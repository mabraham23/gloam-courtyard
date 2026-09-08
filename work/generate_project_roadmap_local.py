"""Generate both local board files from authoritative Markdown task records."""
import argparse
from html import escape
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def roadmap(text):
    match = re.search(r'<!-- roadmap-data:start -->\s*```json\s*([\s\S]*?)```\s*<!-- roadmap-data:end -->', text)
    if not match:
        raise ValueError('Missing authoritative roadmap JSON block')
    data = json.loads(match.group(1))
    if data['schema'] != 1:
        raise ValueError('Unsupported roadmap schema')
    ids = set()
    required = ('id', 'lane', 'area', 'title', 'effort', 'parallel', 'dependency', 'owner', 'evidence', 'description')
    for task in data['tasks']:
        for field in required:
            if not isinstance(task.get(field), str) or not task[field].strip():
                raise ValueError('Missing task field: ' + field)
        if not re.fullmatch('[a-z0-9-]+', task['id']) or task['id'] in ids:
            raise ValueError('Invalid or duplicate task ID: ' + task['id'])
        ids.add(task['id'])
        if task['lane'] not in ('now', 'next', 'waiting', 'later', 'complete'):
            raise ValueError('Unknown task lane')
        if not task.get('evidence_paths'):
            raise ValueError('Task needs an evidence source')
        for name in task['evidence_paths']:
            path = (ROOT / name).resolve()
            if not path.is_relative_to(ROOT) or not path.is_file():
                raise ValueError('Missing or invalid evidence path: ' + name)
    return data


def render():
    data = roadmap((ROOT / 'docs/UPCOMING_TASKS.md').read_text())
    source = (ROOT / 'tools/feedback/roadmap-template.html').read_text()
    payload = json.dumps(data['tasks'], ensure_ascii=False, indent=2).replace('<', '\\u003c')
    source = source.replace('__TASKS_JSON__', payload)
    source = source.replace('__SUMMARY_HTML__', escape(data['summary']))
    phases = ''.join('<div class="gpb-phase"><strong>' + escape(t['title']) + '</strong><p>' + escape(t['lane'] + ' · ' + t['dependency']) + '</p></div>' for t in data['tasks'])
    source = source.replace('__PHASES_HTML__', phases)
    decisions = (ROOT / 'docs/DECISIONS.md').read_text().split('<!-- decision-index:start -->')[1].split('<!-- decision-index:end -->')[0]
    rows = [line.strip().strip('|').split('|') for line in decisions.splitlines() if line.startswith('| D-')]
    timeline = ''.join('<div class="gpb-decision"><time>' + escape(row[0].strip()) + '</time><div><strong>' + escape(row[1].strip()) + '</strong><p>' + escape(row[2].strip()) + '</p></div></div>' for row in rows)
    if not rows:
        raise ValueError('Current decision index is empty')
    source = source.replace('__DECISIONS_HTML__', timeline)
    if re.search(r'__[A-Z_]+__', source):
        raise ValueError('Unfilled template marker')
    return source, wrap(source).rstrip() + "\n", len(data['tasks'])


def wrap(source):
    fragment = escape(source, quote=True).replace("&#x27;", "&#39;")
    return f'''<!doctype html>
    <html lang="en" data-visualize-standalone>
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="referrer" content="no-referrer">
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval' blob: data: https://cdnjs.cloudflare.com https://cdn.jsdelivr.net https://esm.sh https://fonts.bunny.net https://fonts.googleapis.com https://fonts.gstatic.com https://unpkg.com; style-src 'unsafe-inline' blob: data: https://cdnjs.cloudflare.com https://cdn.jsdelivr.net https://esm.sh https://fonts.bunny.net https://fonts.googleapis.com https://fonts.gstatic.com https://unpkg.com; img-src blob: data: https://cdnjs.cloudflare.com https://cdn.jsdelivr.net https://esm.sh https://fonts.bunny.net https://fonts.googleapis.com https://fonts.gstatic.com https://unpkg.com; font-src blob: data: https://cdnjs.cloudflare.com https://cdn.jsdelivr.net https://esm.sh https://fonts.bunny.net https://fonts.googleapis.com https://fonts.gstatic.com https://unpkg.com; media-src blob: data: https://cdnjs.cloudflare.com https://cdn.jsdelivr.net https://esm.sh https://fonts.bunny.net https://fonts.googleapis.com https://fonts.gstatic.com https://unpkg.com; worker-src blob:; connect-src blob: data:; frame-src 'self'; object-src 'none'; base-uri 'none'; form-action 'none'">
    <title>Gloam project board</title>
    <style>:root{{color-scheme:light dark;background:light-dark(rgb(255 255 255), rgb(24 24 24))}}html,body{{margin:0}}body{{box-sizing:border-box;padding:1rem;background:inherit}}iframe{{display:block;width:100%;height:calc(100vh - 2rem);margin:0 auto;border:0}}</style>
    </head>
    <body>
    <iframe sandbox="allow-scripts" referrerpolicy="no-referrer" title="Gloam project board" srcdoc="{fragment}"></iframe>
    </body>
    </html>
    '''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Fail on drift without writing')
    args = parser.parse_args()
    source, local, count = render()
    for name, content in [('project-roadmap.html', source), ('project-roadmap-local.html', local)]:
        path = ROOT / 'work' / name
        if args.check:
            if not path.exists() or path.read_text() != content:
                raise SystemExit('ROADMAP_DRIFT: regenerate ' + name)
        else:
            path.write_text(content)
    print('ROADMAP_' + ('CHECK_OK' if args.check else 'GENERATED') + ' tasks=' + str(count))


if __name__ == '__main__':
    main()
