from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from retention import candidates, apply


class RetentionTests(unittest.TestCase):
    def test_only_old_preserved_raw_is_pruned_and_dirty_source_survives(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for index in range(5):
                run = root / 'work/review-runs' / f'2020010{index}-test'
                (run / 'frames').mkdir(parents=True)
                (run / 'frames/frame.png').write_bytes(b'raw unique frames')
                (run / 'manifest.json').write_text(json.dumps({'created_utc': '2020-01-01T00:00:00+00:00', 'build': {'dirty': True}}))
                (root / '.artifacts/snapshots' / run.name).mkdir(parents=True)
                (root / '.artifacts/snapshots' / run.name / 'source.gd').write_text('uncommitted source')
                if index == 1:  # Only one old run has verified curated evidence.
                    saved = root / 'evidence/one'
                    saved.mkdir(parents=True)
                    (saved / 'preview.webp').write_bytes(b'preserved preview')
                    (saved / 'manifest.json').write_text(json.dumps({'preserved_files': {'preview.webp': hashlib.sha256(b'preserved preview').hexdigest()}}))
                    (run / 'preservation.json').write_text(json.dumps({'curated': str(saved), 'manifest_sha256': hashlib.sha256((saved / 'manifest.json').read_bytes()).hexdigest()}))
            options = {'now': datetime(2026, 9, 8, tzinfo=timezone.utc)}
            plan = candidates(root, **options)
            self.assertEqual(len(plan), 1)
            self.assertEqual(len(plan[0]['paths']), 1)  # Dirty snapshot is retained.
            apply(root, plan, **options)
            self.assertTrue((root / 'work/review-runs/20200100-test/frames').is_dir())
            self.assertFalse((root / 'work/review-runs/20200101-test/frames').exists())
            self.assertTrue((root / '.artifacts/snapshots/20200101-test/source.gd').is_file())
            self.assertTrue((root / 'evidence/one/preview.webp').is_file())


if __name__ == '__main__':
    unittest.main()
