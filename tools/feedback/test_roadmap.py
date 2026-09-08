import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('roadmap', Path(__file__).resolve().parents[2] / 'work/generate_project_roadmap_local.py')
board = importlib.util.module_from_spec(spec)
spec.loader.exec_module(board)


class RoadmapTests(unittest.TestCase):
    def test_generated_source_and_wrapper_are_in_sync(self):
        source, wrapper, count = board.render()
        self.assertEqual(source, (board.ROOT / 'work/project-roadmap.html').read_text())
        self.assertEqual(wrapper, (board.ROOT / 'work/project-roadmap-local.html').read_text())

    def test_duplicate_task_or_missing_evidence_is_rejected(self):
        text = (board.ROOT / 'docs/UPCOMING_TASKS.md').read_text()
        data = board.roadmap(text)
        data['tasks'].append(data['tasks'][0])
        def block(value):
            return '<!-- roadmap-data:start -->\n```json\n' + json.dumps(value) + '\n```\n<!-- roadmap-data:end -->'
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            board.roadmap(block(data))
        data['tasks'].pop()
        data['tasks'][0]['evidence_paths'] = ['docs/missing-evidence.md']
        with self.assertRaisesRegex(ValueError, 'evidence path'):
            board.roadmap(block(data))


if __name__ == '__main__':
    unittest.main()
