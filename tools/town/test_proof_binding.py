"""Real binding mutations: launchers/import policy count, generated copies do not."""
import tempfile
import unittest
from pathlib import Path
import prove_extension as proof

class SourceBinding(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.previous = proof.ROOT
        proof.ROOT = Path(self.tmp.name)
        for path in ['scripts/owner.gd','tests/run_playtest.sh','assets/image.png.import',*proof.EXTRA]:
            self.write(path,'baseline')
        self.baseline = proof.binding()
    def tearDown(self):
        proof.ROOT = self.previous
        self.tmp.cleanup()
    def write(self,path,text):
        out = proof.ROOT/path
        out.parent.mkdir(parents=True,exist_ok=True)
        out.write_text(text)
    def test_launcher_regression_invalidates_proof(self):
        self.write('tests/run_playtest.sh','ignore engine failures')
        self.assertNotEqual(proof.binding(),self.baseline)
    def test_import_policy_invalidates_proof(self):
        self.write('assets/image.png.import','disable mipmaps')
        self.assertNotEqual(proof.binding(),self.baseline)
    def test_review_change_invalidates_proof(self):
        self.write('docs/art/style-audit/current/approval.json','different approval')
        self.assertNotEqual(proof.binding(),self.baseline)
    def test_generated_project_and_reports_are_not_source(self):
        self.write('tools/features/_stage/project/scripts/owner.gd','temporary copy')
        self.write('tools/features/reports/dump.json','temporary report')
        self.assertEqual(proof.binding(),self.baseline)
    def test_data_extension_does_not_change_code(self):
        before = proof.hashes(proof.ROOT,True)
        self.write('lua/extension.lua','new data')
        self.assertNotEqual(proof.binding(),self.baseline)
        self.assertEqual(proof.hashes(proof.ROOT,True),before)
    def test_launcher_is_code_for_extension_contract(self):
        before = proof.hashes(proof.ROOT,True)
        self.write('tests/run_playtest.sh','different launcher')
        self.assertNotEqual(proof.hashes(proof.ROOT,True),before)

if __name__ == '__main__':
    unittest.main()
