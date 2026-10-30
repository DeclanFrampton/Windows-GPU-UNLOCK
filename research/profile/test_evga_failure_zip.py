import importlib.util
import io
import json
from pathlib import Path
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('review', Path(__file__).with_name('review-evga-failure-zip.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def archive(items):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, 'w') as z:
        for name, data in items:
            z.writestr(name, data)
    return stream.getvalue()


class ReviewTests(unittest.TestCase):
    def test_partial_run_and_new_entry(self):
        log = 'capture-complete=1\nevga-unlock-slot-10\nlast-flushed-stage'
        nested = archive([('EVP10.TXT', log), ('EVP10.ARMED', b'STARTED EVP10 - DO NOT REPEAT\r\n' + bytes(470))])
        inspection = {'run': 'EVP10', 'current_entries': [{'name': 'Boot0009', 'previously_in_order': False}]}
        data = archive([('inspection.json', json.dumps(inspection)), ('results.zip', nested)])
        result = module.review(data)
        self.assertFalse(result['transaction_return_recorded'])
        self.assertFalse(result['retry_authorized'])
        self.assertEqual(result['capture_count'], 1)
        self.assertEqual(result['additional_boot_entries'][0]['name'], 'Boot0009')
        self.assertEqual(result['log_tail'][-1], 'last-flushed-stage')

    def test_duplicate_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Ambiguous duplicate'):
            module.review(archive([('a/inspection.json', '{}'), ('b/inspection.json', '{}')]))

    def test_expansion_limit(self):
        old = module.LIMIT
        try:
            module.LIMIT = 1024
            stream = io.BytesIO()
            with zipfile.ZipFile(stream, 'w', compression=zipfile.ZIP_DEFLATED) as z:
                z.writestr('large.txt', bytes(2048))
            with self.assertRaisesRegex(ValueError, 'Expanded archive'):
                module.review(stream.getvalue())
        finally:
            module.LIMIT = old


if __name__ == '__main__':
    unittest.main()
