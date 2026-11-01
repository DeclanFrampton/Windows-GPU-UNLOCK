"""Offline graph export regressions; no firmware or GPU access."""
import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('graph_summary', Path(__file__).with_name('summarize-graph.py'))
graph = importlib.util.module_from_spec(spec)
spec.loader.exec_module(graph)


class GraphSummaryTests(unittest.TestCase):
    def test_graph_relationships_survive_without_raw_paths(self):
        data = (b'handle id=0x1234\nopen agent=0x5 controller=0x6 attributes=0x8 count=0x1\n'
                b'path-node raw=PRIVATE-GUID\nimage-file-path PRIVATE-NAME\n'
                b'image PRIVATE-USER=0x1234\nimage username=0x1234\n'
                b'capture-complete=0\ndiagnostic-result status=0x8000000000000006\n')
        result = graph.summarize(data)
        self.assertEqual(len(result['records']), 2)
        self.assertNotIn('PRIVATE', json.dumps(result))
        self.assertNotIn('username', json.dumps(result))
        self.assertEqual(result['complete_markers'], ['0'])
        self.assertFalse(result['graph_only_marker'])

    def test_pci_header_and_conflicting_footers_are_preserved_as_observations(self):
        line = 'pci config-dwords=' + '220410de ' * 16
        result = graph.summarize((line + '\ncapture-complete=1\ncapture-complete=0\n').encode())
        self.assertEqual(result['records'], [line.rstrip()])
        self.assertEqual(result['complete_markers'], ['1', '0'])

    def test_failure_reasons_survive_without_private_text(self):
        data = (b'incomplete reason=gop-info status=0x8000000000000006\n'
                b'incomplete reason=PRIVATE-PATH status=0x8000000000000006\n'
                b'incomplete reason=gop-info status=PRIVATE\n'
                b'capture-complete=0\n'
                b'diagnostic-result status=0x8000000000000006\n')
        result = graph.summarize(data)
        self.assertEqual(result['incomplete_reason_count'], 3)
        self.assertEqual(result['incomplete_reasons'], [
            {'reason': 'gop-info', 'status': '0x8000000000000006'}])
        self.assertEqual(result['unexported_reason_count'], 2)
        self.assertEqual(result['complete_markers'], ['0'])
        self.assertNotIn('PRIVATE', json.dumps(result))

    def test_duplicate_and_conflicting_reasons_are_not_deduplicated(self):
        result = graph.summarize(
            b'incomplete reason=gop-info status=0x8000000000000006\n'
            b'incomplete reason=gop-info status=0x8000000000000007\n')
        self.assertEqual(len(result['incomplete_reasons']), 2)
        self.assertEqual(result['unexported_reason_count'], 0)

    def test_invalid_encoding_is_not_repaired(self):
        with self.assertRaises(UnicodeError):
            graph.summarize(b'\x8f')


if __name__ == '__main__':
    unittest.main()
