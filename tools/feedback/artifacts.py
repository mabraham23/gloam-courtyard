#!/usr/bin/env python3
"""Inventory and losslessly compact local captures; no unique PNG is deleted."""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import stat
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[2]


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def atomic_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + '.tmp')
    temp.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')
    temp.replace(path)


def inventory(root: Path) -> dict:
    files = []
    for path in sorted((root / 'captures').glob('*')):
        if path.is_symlink() or not path.is_file() or path.suffix not in ('.png', '.wav', '.avi'):
            continue
        info = path.stat()
        item = {'path': str(path.relative_to(root)), 'bytes': info.st_size,
                'sha256': digest(path), 'mtime_ns': info.st_mtime_ns,
                'inode': info.st_ino, 'device': info.st_dev}
        if path.suffix == '.wav':
            try:
                with wave.open(str(path)) as audio:
                    # 8-bit PCM silence is unsigned 128, not zero.
                    sample = b'\x80' if audio.getsampwidth() == 1 else b'\0'
                    silent = True
                    while data := audio.readframes(16384):
                        if data != sample * len(data):
                            silent = False
                            break
                    item['silent_pcm'] = silent
            except (wave.Error, EOFError):
                item['silent_pcm'] = False
        files.append(item)
    unique = {}
    reclaimed = 0
    duplicates = 0
    for item in files:
        key = item['sha256']
        if key in unique:
            duplicates += 1
            if (item['device'], item['inode']) != (unique[key]['device'], unique[key]['inode']):
                reclaimed += item['bytes']
        else:
            unique[key] = item
    return {'schema': 1, 'root': str(root.resolve()), 'files': files,
            'summary': {'files': len(files), 'logical_bytes': sum(x['bytes'] for x in files),
                        'duplicate_files': duplicates, 'duplicate_unshared_bytes': reclaimed,
                        'silent_wav_bytes': sum(x['bytes'] for x in files if x.get('silent_pcm'))}}


def checked_path(root: Path, item: dict) -> Path:
    path = root / item['path']
    if path.is_symlink() or path.resolve().parent != (root / 'captures').resolve():
        raise ValueError('Only direct, regular capture files may be compacted')
    if not path.is_file() or path.stat().st_size != item['bytes'] or digest(path) != item['sha256']:
        raise ValueError(f"Changed since inventory: {item['path']}")
    return path


def compact(root: Path, plan: dict) -> dict:
    if plan['root'] != str(root.resolve()):
        raise ValueError('Plan belongs to a different project')
    # Validate the entire plan before any mutation, including path containment.
    for item in plan['files']:
        checked_path(root, item)
    store = root / '.artifacts' / 'silent-audio'
    store.mkdir(parents=True, exist_ok=True)
    journal_path = root / '.artifacts' / 'compaction.json'
    journal = json.loads(journal_path.read_text()) if journal_path.exists() else {
        'schema': 1, 'audio': {}, 'shared_pngs': {}, 'note': 'PNG aliases are read-only; use unique run names.'}
    canonical = {}
    reclaimed_png = 0
    reclaimed_audio = 0
    for item in plan['files']:
        path = checked_path(root, item)
        sha = item['sha256']
        if item.get('silent_pcm'):
            archive = store / (sha + '.wav.gz')
            if not archive.exists():
                temp = archive.with_suffix('.tmp')
                with path.open('rb') as source, gzip.open(temp, 'wb', compresslevel=9) as target:
                    for chunk in iter(lambda: source.read(1024 * 1024), b''):
                        target.write(chunk)
                temp.replace(archive)
            with gzip.open(archive, 'rb') as stream:
                if hashlib.sha256(stream.read()).hexdigest() != sha:
                    raise ValueError('Compressed audio verification failed')
            journal['audio'][item['path']] = {'sha256': sha, 'bytes': item['bytes'],
                                            'archive': str(archive.relative_to(root))}
            atomic_json(journal_path, journal)  # Recovery mapping exists before raw removal.
            checked_path(root, item).unlink()
            reclaimed_audio += item['bytes']
        elif path.suffix == '.png':
            if sha not in canonical:
                canonical[sha] = path
                continue
            source = canonical[sha]
            if os.path.samefile(source, path):
                continue
            # Immutable hard links preserve every old filename and byte. Never
            # reuse an archived capture prefix for future renderer output.
            if digest(source) != sha:
                raise ValueError('Canonical image changed')
            source.chmod(stat.S_IRUSR | stat.S_IRGRP | stat.S_IROTH)
            fd, name = tempfile.mkstemp(prefix='.compact-', dir=path.parent)
            os.close(fd)
            temp = Path(name)
            temp.unlink()
            try:
                os.link(source, temp)
                checked_path(root, item)
                os.replace(temp, path)
            finally:
                temp.unlink(missing_ok=True)
            journal['shared_pngs'][item['path']] = {'canonical': str(source.relative_to(root)), 'sha256': sha}
            reclaimed_png += item['bytes']
    atomic_json(journal_path, journal)
    return {'png_bytes_shared': reclaimed_png, 'silent_audio_raw_bytes_removed': reclaimed_audio,
            'audio_archive_bytes': sum(p.stat().st_size for p in store.glob('*.gz')),
            'unique_pngs_deleted': 0, 'journal': str(journal_path)}


def restore_audio(root: Path, relative: str) -> Path:
    journal = json.loads((root / '.artifacts/compaction.json').read_text())
    item = journal['audio'][relative]
    path = root / relative
    if path.resolve().parent != (root / 'captures').resolve() or path.is_symlink():
        raise ValueError('Invalid restore destination')
    archive = root / item['archive']
    if archive.resolve().parent != (root / '.artifacts/silent-audio').resolve():
        raise ValueError('Invalid audio archive path')
    with gzip.open(archive, 'rb') as stream:
        data = stream.read()
    if hashlib.sha256(data).hexdigest() != item['sha256']:
        raise ValueError('Archive checksum mismatch')
    if path.exists():
        if digest(path) != item['sha256']:
            raise ValueError('Refusing to overwrite different audio')
        return path
    with path.open('xb') as stream:
        stream.write(data)
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    sub = parser.add_subparsers(dest='command', required=True)
    scan = sub.add_parser('inventory')
    scan.add_argument('--out', type=Path)
    apply = sub.add_parser('compact')
    apply.add_argument('--plan', required=True, type=Path)
    apply.add_argument('--apply', action='store_true', help='Required for mutation; otherwise show plan summary')
    restore = sub.add_parser('restore-audio')
    restore.add_argument('path')
    args = parser.parse_args()
    root = args.root.resolve()
    if args.command == 'inventory':
        plan = inventory(root)
        atomic_json(args.out or root / '.artifacts/capture-inventory.json', plan)
        print(json.dumps(plan['summary'], indent=2))
    elif args.command == 'compact':
        plan = json.loads(args.plan.read_text())
        print(json.dumps(compact(root, plan) if args.apply else plan['summary'], indent=2))
    else:
        print(restore_audio(root, args.path))


if __name__ == '__main__':
    main()
