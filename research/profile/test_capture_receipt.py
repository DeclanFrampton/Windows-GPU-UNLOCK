"""Exercise the real offline launcher; empty fixtures, no GPU access."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]

class ReceiptTests(unittest.TestCase):
    def test_real_launcher_binds_report_and_source_without_private_paths(self):
        with tempfile.TemporaryDirectory() as folder:
            base=Path(folder);captures=base/'existing captures';captures.mkdir()
            ids=[]
            for repeat in range(2):
                before=set(base.glob('GPU-Unlock-Capture-Check-*'))
                process=subprocess.run(['powershell','-NoProfile','-File',str(ROOT/'tools/test-existing-captures.ps1'),
                    '-Captures',str(captures),'-Python',sys.executable,'-OutputRoot',str(base)],
                    capture_output=True,text=True,timeout=40)
                self.assertEqual(process.returncode,0,process.stdout+process.stderr)
                output=(set(base.glob('GPU-Unlock-Capture-Check-*'))-before).pop()
                receipt=json.loads((output/'result.json').read_text(encoding='utf-8-sig'))
                report=json.loads((output/'report.json').read_text(encoding='utf-8-sig'))
                self.assertEqual(receipt['test'],'existing-capture-refusal-v2')
                self.assertEqual(receipt['phase'],'done')
                self.assertEqual(receipt['status'],report['status'])
                self.assertFalse(report['write_eligible']);self.assertFalse(report['hardware_tested'])
                self.assertEqual(receipt['report_sha256'],hashlib.sha256((output/'report.json').read_bytes()).hexdigest())
                self.assertEqual(len(receipt['source_sha256']),4)
                for name,digest in receipt['source_sha256'].items():
                    self.assertEqual(digest,hashlib.sha256((ROOT/name).read_bytes()).hexdigest())
                self.assertNotIn(str(base),json.dumps(receipt))
                self.assertRegex(receipt['run_id'],r'^[0-9a-f]{32}$');ids.append(receipt['run_id'])
            self.assertNotEqual(*ids)

if __name__=='__main__':unittest.main()
