#!/usr/bin/env python3
"""Frozen, bounded Godot review scenarios. Run `python3 tools/review.py --help`."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
import html
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
SCENARIOS = {
    'locomotion': {'script': 'work/action-quality/single_speed_sequence.gd', 'frames': 210,
                   'footer': 'R14_SINGLE_SPEED_SEQUENCE_OK', 'args': [],
                   'question': 'Do the knees track forward and does run/start/stop read naturally?',
                   'helpers': 'Fixed 30 Hz held-input controller; guard moved away; diagnostic profile camera; world labels hidden.'},
    'locomotion-front': {'script': 'work/action-quality/single_speed_sequence.gd', 'frames': 210,
                         'footer': 'R14_SINGLE_SPEED_SEQUENCE_OK', 'args': ['--front'],
                         'question': 'Does front-view stance and knee tracking improve without narrowing the gait unnaturally?',
                         'helpers': 'Same real-controller travel as locomotion; diagnostic front camera and guard placement.'},
    'actions': {'script': 'work/action-quality/action_motion_sequence.gd', 'frames': 277,
                'footer': 'R7_ACTION_MOTION_SEQUENCE_OK', 'args': [],
                'keyframes': [0, 4, 9, 88, 91, 132, 168, 178, 242],
                'question': 'Are strike contact/recovery, forward evade and paired takedown readable?',
                'helpers': 'Fixed-step paired action fixture; helper actor placement and review cameras.'},
}
SOURCE_SUFFIXES = {'.gd', '.tscn', '.tres', '.godot', '.json', '.glb', '.bvh', '.import', '.png'}


def git(*args, cwd=ROOT) -> str:
    return subprocess.check_output(['git', *args], cwd=cwd, text=True).strip()


def atomic_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + '.tmp')
    temp.write_text(json.dumps(data, indent=2, sort_keys=True) + '\n')
    temp.replace(path)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fingerprint(project: Path) -> dict:
    files = []
    for base in ['actors', 'levels', 'debug']:
        if (project / base).exists():
            files.extend(p for p in (project / base).rglob('*') if p.is_file() and p.suffix in SOURCE_SUFFIXES
                         and not any(x in p.parts for x in ('renders', 'revisions', 'reference', 'source')))
    if (project / 'work').exists():
        files.extend(p for p in (project / 'work').rglob('*.gd') if 'review-runs' not in p.parts)
    files.extend(p for p in project.glob('*') if p.is_file() and not p.name.startswith('.') and p.suffix in SOURCE_SUFFIXES)
    sources = {p.relative_to(project).as_posix(): sha(p) for p in sorted(files)}
    joined = ''.join(f'{name}={value}\n' for name, value in sorted(sources.items()))
    return {'sha256': hashlib.sha256(joined.encode()).hexdigest(), 'files': sources}


def snapshot(destination: Path, ref: str | None) -> dict:
    destination.mkdir(parents=True)
    if ref:
        revision = git('rev-parse', '--verify', ref + '^{commit}')
        archive = destination.parent / 'source.tar'
        with archive.open('wb') as output:
            subprocess.run(['git', 'archive', revision], cwd=ROOT, stdout=output, check=True)
        with tarfile.open(archive) as source:
            source.extractall(destination, filter='data')
        archive.unlink()
        dirty = False
    else:
        revision = git('rev-parse', 'HEAD')
        names = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT).decode().split('\0')
        before = {}
        for name in sorted(set(filter(None, names))):
            source = ROOT / name
            if source.is_symlink() or not source.is_file():
                raise ValueError('Snapshot requires regular existing files: ' + name)
            before[name] = sha(source)
            target = destination / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        if any(sha(ROOT / name) != value for name, value in before.items()):
            raise ValueError('Source changed while snapshotting; retry after the owner finishes')
        dirty = bool(git('status', '--porcelain'))
    identity = fingerprint(destination)
    result = {'schema': 1, 'commit': revision, 'dirty': dirty, 'source': identity,
              'source_project': str(ROOT), 'snapshot_project': str(destination),
              'created_utc': datetime.now(timezone.utc).isoformat()}
    atomic_json(destination / '.review-build.json', result)
    return result


def validate_log(log: str, footer: str) -> None:
    if any(marker in log for marker in ('SCRIPT ERROR:', 'Parse Error:', 'Assertion failed', 'ERROR: Failed to load')):
        raise RuntimeError('Godot script/resource failure; inspect the run log')
    if footer and footer not in log:
        raise RuntimeError('Missing required completion marker: ' + footer)


def command(argv: list[str], log: Path, timeout: int, footer='') -> float:
    start = time.monotonic()
    with log.open('w') as output:
        process = subprocess.Popen(argv, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            raise RuntimeError(f'Timed out after {timeout}s: {log.name}')
    content = log.read_text(errors='replace')
    if code:
        raise RuntimeError(f'Exit {code}: {log}')
    validate_log(content, footer)
    return round(time.monotonic() - start, 3)


def normal_renderers(listing: str) -> list[str]:
    # Relative --path launches still consume the same GPU. Match the executable,
    # not the project argument, and refuse any other normal Godot renderer.
    pattern = r'^\s*\d+\s+(?:\S*/)?(?:Godot|godot)(?:\s|$)'
    return [line.strip() for line in listing.splitlines()
            if re.match(pattern, line) and '--headless' not in line]


def game_processes() -> list[str]:
    return normal_renderers(subprocess.check_output(['ps', '-axo', 'pid=,command='], text=True))


@contextmanager
def render_lease():
    path = ROOT / '.artifacts/render.lock'
    path.parent.mkdir(exist_ok=True)
    with path.open('a+') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('Another review/performance run owns the renderer')
        existing = game_processes()
        if existing:
            raise RuntimeError('Close the owned live Godot window before rendering; no processes were stopped: ' + '; '.join(existing))
        lock.seek(0)
        lock.truncate()
        lock.write(json.dumps({'owner_pid': os.getpid(), 'purpose': 'bounded review', 'project': str(ROOT)}))
        lock.flush()
        yield


def media_python() -> str:
    config = ROOT / '.artifacts/toolchain.json'
    value = json.loads(config.read_text()).get('media_python') if config.exists() else None
    executable = os.environ.get('GLOAM_MEDIA_PYTHON', value or sys.executable)
    subprocess.run([executable, '-c', 'from PIL import Image'], check=True, capture_output=True)
    return executable


def run(args) -> Path:
    config = SCENARIOS[args.scenario]
    godot = args.godot or shutil.which('godot')
    if not godot:
        raise RuntimeError('Install Godot or use --godot /path/to/Godot')
    preview_python = media_python()  # Fail early, before expensive capture.
    run_id = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + args.scenario + '-' + uuid.uuid4().hex[:6]
    directory = ROOT / 'work/review-runs' / run_id
    project = ROOT / '.artifacts/snapshots' / run_id / 'project'
    directory.mkdir(parents=True)
    (directory.parent / '.gdignore').touch()
    (directory / 'frames').mkdir()
    start = time.monotonic()
    result = {'schema': 1, 'id': run_id, 'scenario': args.scenario, 'status': 'diagnostic',
              'technical_pass': False, 'visual_verdict': 'unreviewed', 'question': config['question'],
              'helpers': config['helpers'], 'seed': args.seed, 'fps': 30, 'resolution': [960, 600],
              'renderer': 'gl_compatibility', 'native_input': False, 'timings': {},
              'created_utc': datetime.now(timezone.utc).isoformat()}
    try:
        result['runner_sha256'] = sha(Path(__file__).resolve())
        shutil.copy2(Path(__file__).resolve(), directory / 'review-runner.py')
        result['build'] = snapshot(project, args.ref)
        asset = project / 'actors/gloam_vigil/v4/gloam_vigil_player_v4.glb'
        result['asset_sha256'] = sha(asset)
        if args.expect_asset and result['asset_sha256'] != args.expect_asset:
            raise ValueError('Candidate asset checksum does not match --expect-asset')
        script = project / config['script']
        result['fixture_sha256'] = sha(script)
        # Deterministic environment generation, while preserving the actual
        # fixture/controller. Test positioning never claims native reachability.
        wrapper = project / 'review_entry.gd'
        wrapper.write_text('extends "res://' + config['script'] + '"\n\nfunc _initialize() -> void:\n\tseed(' + str(args.seed) + ')\n\tsuper._initialize()\n' +
            '\nfunc _start() -> void:\n\tsuper._start()\n\tvar imported: Node = game.player_visual_parts["authored_rig"]["imported_root"]\n' +
            '\tassert(imported.scene_file_path == "res://actors/gloam_vigil/v4/gloam_vigil_player_v4.glb", "Wrong runtime candidate path")\n' +
            '\tassert(FileAccess.get_sha256(imported.scene_file_path) == "' + result['asset_sha256'] + '", "Wrong runtime candidate SHA")\n' +
            '\tprint("REVIEW_RUNTIME_ASSET_OK sha=' + result['asset_sha256'] + '")\n')
        result['wrapper_sha256'] = sha(wrapper)
        result['timings']['snapshot_s'] = round(time.monotonic() - start, 3)
        result['engine'] = subprocess.check_output([godot, '--version'], text=True).strip()
        result['timings']['import_s'] = command([godot, '--headless', '--path', str(project), '--editor', '--quit'], directory / 'import.log', 120)
        with render_lease():
            result['timings']['render_s'] = command([godot, '--path', str(project), '--rendering-method', 'gl_compatibility',
                '--resolution', '960x600', '--script', str(wrapper), '--write-movie', str(directory / 'frames/frame.png'),
                '--fixed-fps', '30', '--disable-vsync', '--quit-after', str(config['frames'] + 3), '--', *config['args']],
                directory / 'render.log', 120, config['footer'])
        validate_log((directory / 'render.log').read_text(), 'REVIEW_RUNTIME_ASSET_OK')
        frames = sorted((directory / 'frames').glob('frame*.png'))
        if not config['frames'] <= len(frames) <= config['frames'] + 3:
            raise ValueError(f'Unexpected frame count: {len(frames)}')
        result['frames'] = {path.name: sha(path) for path in frames}
        result['timings']['first_review_s'] = round(time.monotonic() - start, 3)
        media_start = time.monotonic()
        media_args = [preview_python, str(ROOT / 'tools/feedback/media.py'), str(directory)]
        if config.get('keyframes'):
            media_args.extend(['--keyframes', ','.join(map(str, config['keyframes']))])
        media = subprocess.check_output(media_args, text=True)
        result['preview'] = json.loads(media)
        result['timings']['preview_s'] = round(time.monotonic() - media_start, 3)
        result['technical_pass'] = True
    except Exception as error:
        result['error'] = str(error)
        result['status'] = 'failed'
        raise
    finally:
        result['timings']['total_s'] = round(time.monotonic() - start, 3)
        if (project / '.godot').exists():
            shutil.rmtree(project / '.godot')  # Generated cache; all child processes have exited.
        if args.ref and result.get('build'):
            shutil.rmtree(project.parent)
            result['source_retention'] = 'Recreate from recorded immutable Git commit; clean temporary checkout removed.'
        else:
            result['source_retention'] = 'Dirty source snapshot retained locally; generated import cache removed.'
        atomic_json(directory / 'manifest.json', result)
        print(json.dumps({'run': str(directory), 'technical_pass': result['technical_pass'], 'timings': result['timings'], 'error': result.get('error')}), flush=True)
    return directory


def compare(before: Path, after: Path, output: Path) -> None:
    first = json.loads((before / 'manifest.json').read_text())
    second = json.loads((after / 'manifest.json').read_text())
    for key in ('scenario', 'seed', 'fps', 'resolution', 'renderer', 'helpers', 'fixture_sha256', 'engine'):
        if key not in first or key not in second or first[key] != second[key]:
            raise ValueError('Comparison setup differs: ' + key)
    if not first['technical_pass'] or not second['technical_pass']:
        raise ValueError('Both runs must pass fixture checks before comparison')
    output.mkdir(parents=True, exist_ok=False)
    for label, source in [('before', before), ('after', after)]:
        shutil.copy2(source / 'preview.webp', output / (label + '.webp'))
        shutil.copy2(source / 'contact-sheet.jpg', output / (label + '.jpg'))
    atomic_json(output / 'comparison.json', {'before': first, 'after': second,
                'question': second['question'], 'visual_verdict': 'unreviewed', 'native_acceptance': False})
    page = '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Gloam matched review</title><style>body{background:#111522;color:#eef;font:16px system-ui;margin:24px}main{display:flex;gap:20px;flex-wrap:wrap}section{flex:1;min-width:280px}img{width:100%}code{overflow-wrap:anywhere}</style>'
    page += '<h1>Matched ' + html.escape(first['scenario']) + ' review</h1><p>' + html.escape(second['question']) + '</p><p>Fixed 30 Hz helper-driven evidence. User visual judgement is pending.</p><main>'
    for label, data in [('before', first), ('after', second)]:
        page += '<section><h2>' + label.title() + '</h2><p><code>' + data['build']['source']['sha256'][:12] + '</code></p><img src="' + label + '.webp"><img src="' + label + '.jpg"></section>'
    (output / 'index.html').write_text(page + '</main>')



def live(args) -> None:
    godot = args.godot or shutil.which('godot')
    if not godot:
        raise RuntimeError('Godot executable is required')
    run_id = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-live-' + uuid.uuid4().hex[:6]
    directory = ROOT / 'work/review-runs' / run_id
    project = ROOT / '.artifacts/snapshots' / run_id / 'project'
    directory.mkdir(parents=True)
    (directory.parent / '.gdignore').touch()
    build = snapshot(project, None)
    build['visual'] = 'R14 candidate' if args.candidate else 'V1 default'
    if args.candidate:
        build['asset_sha256'] = sha(project / 'actors/gloam_vigil/v4/gloam_vigil_player_v4.glb')
    atomic_json(project / '.review-build.json', build)
    command([godot, '--headless', '--path', str(project), '--editor', '--quit'], directory / 'import.log', 120)
    argv = [godot, '--path', str(project), '--rendering-method', 'gl_compatibility', '--resolution', '960x600',
            '--script', str(project / 'debug/review_live.gd'), '--']
    if args.candidate:
        argv.append('--candidate')
    if args.capture_smoke:
        argv.append('--capture-smoke')
    environment = dict(os.environ, GLOAM_CAPTURE_DIR=str(ROOT / 'captures'))
    with render_lease(), (directory / 'live.log').open('w') as log:
        process = subprocess.Popen(argv, stdout=log, stderr=subprocess.STDOUT, env=environment)
        record = {'schema': 1, 'pid': process.pid, 'run': str(directory), 'project': str(project),
                  'build': build, 'purpose': 'ordinary input review', 'candidate': args.candidate}
        atomic_json(ROOT / '.artifacts/live.json', record)
        print(json.dumps({'live_pid': process.pid, 'run': str(directory), 'source': build['source']['sha256']}), flush=True)
        try:
            code = process.wait(timeout=60 if args.capture_smoke else None)
        except (KeyboardInterrupt, subprocess.TimeoutExpired):
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            raise
        if code:
            raise RuntimeError('Live review exited with code ' + str(code))
        validate_log((directory / 'live.log').read_text(), 'REVIEW_CAPTURE_SMOKE_OK' if args.capture_smoke else 'REVIEW_IDENTITY_READY')


def curate(run_directory: Path, destination: Path, verdict: str, reason: str) -> None:
    manifest = json.loads((run_directory / 'manifest.json').read_text())
    if not manifest['technical_pass']:
        raise ValueError('Failed run cannot be curated as visual evidence')
    destination.mkdir(parents=True, exist_ok=False)
    files = ['preview.webp', 'contact-sheet.jpg', 'render.log', 'import.log']
    if (run_directory / 'review-runner.py').exists():
        files.append('review-runner.py')
    files.extend(str(p.relative_to(run_directory)) for p in (run_directory / 'keyframes').glob('*.png'))
    checksums = {}
    for name in files:
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(run_directory / name, target)
        checksums[name] = sha(target)
    manifest['visual_verdict'] = verdict
    manifest['review_reason'] = reason
    manifest['preserved_files'] = checksums
    atomic_json(destination / 'manifest.json', manifest)
    atomic_json(run_directory / 'preservation.json', {'curated': str(destination), 'manifest_sha256': sha(destination / 'manifest.json')})
    print(destination)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    capture = sub.add_parser('run')
    capture.add_argument('scenario', choices=SCENARIOS)
    capture.add_argument('--ref', help='Existing Git revision; omitted means a checked snapshot of current files')
    capture.add_argument('--expect-asset')
    capture.add_argument('--seed', type=int, default=1729)
    capture.add_argument('--godot')
    pair = sub.add_parser('compare')
    pair.add_argument('before', type=Path)
    pair.add_argument('after', type=Path)
    pair.add_argument('--output', required=True, type=Path)
    native = sub.add_parser('live')
    native.add_argument('--candidate', action='store_true')
    native.add_argument('--capture-smoke', action='store_true', help='Automated capture test; no native-input acceptance')
    native.add_argument('--godot')
    save = sub.add_parser('curate')
    save.add_argument('run', type=Path)
    save.add_argument('--output', required=True, type=Path)
    save.add_argument('--verdict', choices=['diagnostic', 'rejected', 'accepted'], required=True)
    save.add_argument('--reason', required=True)
    sub.add_parser('identity')
    args = parser.parse_args()
    if args.command == 'run':
        run(args)
    elif args.command == 'compare':
        compare(args.before.resolve(), args.after.resolve(), args.output.resolve())
    elif args.command == 'live':
        live(args)
    elif args.command == 'curate':
        curate(args.run.resolve(), args.output.resolve(), args.verdict, args.reason)
    else:
        data = {'schema': 1, 'commit': git('rev-parse', 'HEAD'), 'dirty': bool(git('status', '--porcelain')),
                'source': fingerprint(ROOT), 'source_project': str(ROOT),
                'created_utc': datetime.now(timezone.utc).isoformat()}
        atomic_json(ROOT / '.review-build.json', data)
        print(json.dumps({'commit': data['commit'], 'dirty': data['dirty'], 'source': data['source']['sha256']}))


if __name__ == '__main__':
    main()
