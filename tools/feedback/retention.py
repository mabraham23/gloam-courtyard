#!/usr/bin/env python3
"""Dry-run-first retention for managed reviews; legacy captures are untouched."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def candidates(root, age_days=14, keep=3, now=None):
    if age_days < 1 or keep < 1:
        raise ValueError('Always keep at least one recent run and one day of raw evidence')
    now = now or datetime.now(timezone.utc)
    runs = sorted((root / 'work/review-runs').glob('*/manifest.json'), reverse=True)
    result = []
    for manifest_path in runs[keep:]:
        directory = manifest_path.parent
        if directory.is_symlink() or not (directory / 'preservation.json').is_file():
            continue
        manifest = json.loads(manifest_path.read_text())
        if (now - datetime.fromisoformat(manifest['created_utc'])).total_seconds() < age_days * 86400:
            continue
        if manifest.get('pinned'):
            continue
        record = json.loads((directory / 'preservation.json').read_text())
        preserved = Path(record['curated'])
        if not preserved.resolve().is_relative_to((root / 'evidence').resolve()):
            continue
        if sha(preserved / 'manifest.json') != record['manifest_sha256']:
            raise ValueError('Curated manifest changed; retain raw evidence')
        saved = json.loads((preserved / 'manifest.json').read_text())
        for relative, expected in saved['preserved_files'].items():
            path = preserved / relative
            if not path.resolve().is_relative_to(preserved.resolve()) or sha(path) != expected:
                raise ValueError('Curated evidence changed; retain raw evidence')
        frames = directory / 'frames'
        if frames.is_symlink() or not frames.is_dir():
            continue
        paths = [frames]
        # Dirty source snapshots can contain otherwise uncommitted changes.
        # Never discard them automatically. Clean source is recoverable by Git.
        snapshot = root / '.artifacts/snapshots' / directory.name
        if not manifest['build']['dirty'] and snapshot.is_dir() and not snapshot.is_symlink():
            paths.append(snapshot)
        result.append({'run': directory.name, 'paths': [str(p) for p in paths],
                       'bytes': sum(p.stat().st_size for base in paths for p in base.rglob('*') if p.is_file())})
    return result


def apply(root, plan, **options):
    if plan != candidates(root, **options):
        raise ValueError('Retention plan changed; no files removed')
    for item in plan:
        for name in item['paths']:
            shutil.rmtree(name)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--age-days', type=int, default=14)
    parser.add_argument('--keep', type=int, default=3)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    options = {'age_days': args.age_days, 'keep': args.keep}
    plan = candidates(ROOT, **options)
    print(json.dumps({'apply': args.apply, 'eligible_runs': plan, 'reclaimable_bytes': sum(p['bytes'] for p in plan)}, indent=2))
    if args.apply:
        apply(ROOT, plan, **options)
