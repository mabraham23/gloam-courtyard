#!/usr/bin/env python3
"""Create and verify a portable milestone archive; never remove the originals."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for data in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(data)
    return h.hexdigest()


def relative(name):
    p = PurePosixPath(name)
    if p.is_absolute() or '..' in p.parts or '\\' in name or name == 'manifest.json':
        raise ValueError('Invalid archive path: ' + name)
    return p


def build(selection, output):
    files = {}
    for entry in selection['entries']:
        path = ROOT / relative(entry['path'])
        for source in sorted(path.rglob('*')) if path.is_dir() else [path]:
            if source.is_dir():
                continue
            if source.is_symlink() or not source.is_file():
                raise ValueError('Only regular files can be archived')
            name = source.relative_to(ROOT).as_posix()
            files[name] = {'sha256': digest(source), 'bytes': source.stat().st_size, 'reason': entry['reason']}
    manifest = {'schema': 1, 'purpose': selection['purpose'], 'files': files}
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name, item in files.items():
            archive.write(ROOT / name, name)
            if digest(ROOT / name) != item['sha256']:
                raise ValueError('File changed during archive creation: ' + name)
        archive.writestr('manifest.json', json.dumps(manifest, indent=2) + '\n')
    verify(output)
    return {'archive': output.name, 'sha256': digest(output), 'archive_bytes': output.stat().st_size,
            'source_bytes': sum(x['bytes'] for x in files.values()), 'files': len(files)}


def verify(path, destination=None):
    with zipfile.ZipFile(path) as archive:
        manifest = json.loads(archive.read('manifest.json'))
        expected = set(manifest['files']) | {'manifest.json'}
        if len(archive.namelist()) != len(expected) or set(archive.namelist()) != expected:
            raise ValueError('Archive entries differ from its manifest')
        for name, item in manifest['files'].items():
            relative(name)
            h = hashlib.sha256()
            size = 0
            with archive.open(name) as stream:
                for data in iter(lambda: stream.read(1024 * 1024), b''):
                    size += len(data)
                    h.update(data)
            if size != item['bytes'] or h.hexdigest() != item['sha256']:
                raise ValueError('Archive checksum mismatch: ' + name)
        # Validate everything before writing, and require a new destination.
        if destination:
            destination.mkdir(parents=True, exist_ok=False)
            for name in manifest['files']:
                target = destination / relative(name)
                target.parent.mkdir(parents=True, exist_ok=True)
                with target.open('xb') as output, archive.open(name) as source:
                    for data in iter(lambda: source.read(1024 * 1024), b''):
                        output.write(data)
        return len(manifest['files'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    create = sub.add_parser('build')
    create.add_argument('selection', type=Path)
    create.add_argument('--output', type=Path, required=True)
    check = sub.add_parser('verify')
    check.add_argument('archive', type=Path)
    check.add_argument('--restore-to', type=Path)
    args = parser.parse_args()
    if args.command == 'build':
        print(json.dumps(build(json.loads(args.selection.read_text()), args.output), indent=2))
    else:
        print(json.dumps({'verified_files': verify(args.archive, args.restore_to)}))
