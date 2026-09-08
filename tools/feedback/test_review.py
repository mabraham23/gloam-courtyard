import importlib.util
import json
from pathlib import Path
import tempfile
import subprocess
import unittest

spec = importlib.util.spec_from_file_location('review', Path(__file__).resolve().parents[1] / 'review.py')
review = importlib.util.module_from_spec(spec)
spec.loader.exec_module(review)


class ReviewTests(unittest.TestCase):
    def test_engine_exit_zero_does_not_hide_script_failure(self):
        for text in ['SCRIPT ERROR: Assertion failed\nDONE', 'Parse Error: bad resource\nDONE', 'no footer']:
            with self.assertRaises(RuntimeError):
                review.validate_log(text, 'DONE')
        review.validate_log('normal output\nDONE', 'DONE')

    def test_build_identity_ignores_itself_and_detects_code_change(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root / 'main_3d.gd'
            source.write_text('extends Node3D\n')
            first = review.fingerprint(root)['sha256']
            (root / '.review-build.json').write_text('{"old":"identity"}')
            self.assertEqual(first, review.fingerprint(root)['sha256'])
            source.write_text('extends Node3D\n# changed\n')
            self.assertNotEqual(first, review.fingerprint(root)['sha256'])
            second = review.fingerprint(root)['sha256']
            (root / 'work').mkdir()
            (root / 'work/candidate_fixture.gd').write_text('extends RefCounted\n')
            self.assertNotEqual(second, review.fingerprint(root)['sha256'])
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            third = review.fingerprint(root)['sha256']
            (root / '.gitignore').write_text('old-export.glb\n')
            (root / 'old-export.glb').write_bytes(b'ignored historic asset')
            self.assertEqual(third, review.fingerprint(root)['sha256'])

    def test_mismatched_comparison_rejected_before_output(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name, seed in [('before', 1), ('after', 2)]:
                (root / name).mkdir()
                (root / name / 'manifest.json').write_text(json.dumps({'scenario': 'locomotion', 'seed': seed}))
            with self.assertRaisesRegex(ValueError, 'seed'):
                review.compare(root / 'before', root / 'after', root / 'output')
            self.assertFalse((root / 'output').exists())

    def test_renderer_lease_detects_relative_project_paths(self):
        listing = '42 /Applications/Godot.app/Contents/MacOS/Godot --path .\n43 /opt/homebrew/bin/godot --headless --path .\n44 /bin/zsh -c Godot --path .'
        self.assertEqual(len(review.normal_renderers(listing)), 1)
        self.assertTrue(review.normal_renderers(listing)[0].startswith('42 '))

    def test_action_footer_matches_real_fixture(self):
        fixture = review.ROOT / review.SCENARIOS['actions']['script']
        self.assertIn(review.SCENARIOS['actions']['footer'], fixture.read_text())


if __name__ == '__main__':
    unittest.main()
