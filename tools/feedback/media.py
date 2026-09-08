"""Small review previews; original PNGs remain the measurement evidence."""
import argparse
import json
import shutil
from pathlib import Path
from PIL import Image, ImageDraw


def render_preview(run: Path, fps: int = 30, indices: list[int] | None = None) -> dict:
    paths = sorted((run / 'frames').glob('frame*.png'))
    if not paths:
        raise ValueError('No capture frames')
    selected = sorted(set(indices)) if indices else sorted(set(round((len(paths) - 1) * i / 8) for i in range(9)))
    if len(selected) > 9 or any(i < 0 or i >= len(paths) for i in selected):
        raise ValueError('Keyframe selection is outside this run or exceeds nine frames')
    sheet = Image.new('RGB', (960, 654), '#10121b')
    draw = ImageDraw.Draw(sheet)
    keyframes = run / 'keyframes'
    keyframes.mkdir(exist_ok=True)
    frames = []
    for index, path in enumerate(paths):
        with Image.open(path) as source:
            source.load()
            if index in selected:
                shutil.copy2(path, keyframes / path.name)
                thumb = source.convert('RGB')
                thumb.thumbnail((320, 200))
                n = selected.index(index)
                x, y = n % 3 * 320, n // 3 * 218
                sheet.paste(thumb, (x, y))
                draw.text((x + 4, y + 201), f'frame {index} | {index / fps:.3f}s', fill='white')
            frame = source.convert('RGB')
            frame.thumbnail((640, 400))
            frames.append(frame)
    durations = [round((i + 1) * 1000 / fps) - round(i * 1000 / fps) for i in range(len(frames))]
    frames[0].save(run / 'preview.webp', save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, quality=85, method=3)
    sheet.save(run / 'contact-sheet.jpg', quality=90)
    with Image.open(run / 'preview.webp') as check:
        if check.n_frames < 2:
            raise ValueError('Preview is not animated')
    return {'frames': len(paths), 'keyframes': len(selected), 'selected_indices': selected, 'preview_bytes': (run / 'preview.webp').stat().st_size,
            'duration_ms': sum(durations), 'preview_note': '640px lossy review preview; timing from fixed-step fixture, not real-time performance.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('run', type=Path)
    parser.add_argument('--fps', type=int, default=30)
    parser.add_argument('--keyframes', help='Comma-separated fixture phase frame indices')
    args = parser.parse_args()
    indices = [int(n) for n in args.keyframes.split(',')] if args.keyframes else None
    print(json.dumps(render_preview(args.run, args.fps, indices)))
