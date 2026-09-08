import json
import os
from pathlib import Path
import tempfile
import unittest
import wave

from artifacts import compact, digest, inventory, restore_audio


class PreservationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'captures').mkdir()

    def test_duplicate_paths_and_bytes_survive_and_audio_roundtrips(self):
        a = self.root / 'captures/a.png'
        b = self.root / 'captures/b.png'
        a.write_bytes(b'fixture pixel data')
        b.write_bytes(a.read_bytes())
        audio = self.root / 'captures/silent.wav'
        with wave.open(str(audio), 'wb') as out:
            out.setparams((1, 2, 8000, 0, 'NONE', 'NONE'))
            out.writeframes(b'\0' * 16000)
        original = digest(audio)
        compact(self.root, inventory(self.root))
        self.assertTrue(os.path.samefile(a, b))
        self.assertEqual(a.read_bytes(), b'fixture pixel data')
        self.assertEqual(b.stat().st_mode & 0o222, 0)
        self.assertFalse(audio.exists())
        restore_audio(self.root, 'captures/silent.wav')
        self.assertEqual(digest(audio), original)

    def test_changed_file_aborts_before_any_compaction(self):
        for name in ['a', 'b', 'z']:
            (self.root / f'captures/{name}.png').write_bytes(b'original')
        plan = inventory(self.root)
        (self.root / 'captures/z.png').write_bytes(b'edited')
        with self.assertRaises(ValueError):
            compact(self.root, plan)
        self.assertFalse(os.path.samefile(self.root / 'captures/a.png', self.root / 'captures/b.png'))

    def test_symlink_and_escape_are_rejected(self):
        outside = self.root / 'outside.png'
        outside.write_bytes(b'private')
        (self.root / 'captures/link.png').symlink_to(outside)
        self.assertEqual(inventory(self.root)['files'], [])
        plan = {'root': str(self.root), 'files': [{'path': 'captures/../outside.png',
                'bytes': outside.stat().st_size, 'sha256': digest(outside)}]}
        with self.assertRaises(ValueError):
            compact(self.root, plan)

    def test_non_silent_and_unsigned_audio_are_distinguished(self):
        for name, samples in [('silence', b'\x80' * 20), ('sound', b'\0' * 20)]:
            with wave.open(str(self.root / f'captures/{name}.wav'), 'wb') as out:
                out.setparams((1, 1, 8000, 0, 'NONE', 'NONE'))
                out.writeframes(samples)
        values = {Path(x['path']).stem: x['silent_pcm'] for x in inventory(self.root)['files']}
        self.assertEqual(values, {'silence': True, 'sound': False})


if __name__ == '__main__':
    unittest.main()
