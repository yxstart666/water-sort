from pathlib import Path
import json,tempfile,unittest
import controlled_save_migration as m
class MigrationTest(unittest.TestCase):
    def setUp(self):
        self.workspace_samples=Path(__file__).resolve().parent.parent/'controlled_migration_samples'
        self.workspace_samples.mkdir(exist_ok=True)
        self.temp=tempfile.TemporaryDirectory(dir=self.workspace_samples);self.root=Path(self.temp.name)
        (self.root/'CONTROLLED_SAMPLES_ONLY').touch()
        self.data={'schema':2,'campaign':'water_sort_orders_v3','pending_attempt':{'id':'water_sort_orders_v3:1','board_digest':'old-board','moves':7},'records':{},'seen_mechanics':['covered_lock_v1']}
        (self.root/'old.json').write_text(json.dumps(self.data),encoding='utf8')
    def tearDown(self):
        assert self.root.resolve().is_relative_to(self.workspace_samples.resolve())
        self.temp.cleanup()
    def test_dry_run_zero_writes(self):
        before=list(self.root.rglob('*'));m.plan(self.root,'old.json','new.json');self.assertEqual(before,list(self.root.rglob('*')))
    def test_copy_and_rollback_preserve_original(self):
        before=m.sha(self.root/'old.json');r=m.apply(self.root,m.plan(self.root,'old.json','new.json'));self.assertEqual(before,m.sha(self.root/'new.json'));self.assertEqual(self.data,json.loads((self.root/'new.json').read_text()));m.rollback(self.root,r);self.assertFalse((self.root/'new.json').exists());self.assertEqual(before,m.sha(self.root/'old.json'))
    def test_source_changed(self):
        p=m.plan(self.root,'old.json','new.json');(self.root/'old.json').write_text('{}')
        with self.assertRaises(ValueError):m.apply(self.root,p)
        self.assertFalse((self.root/'new.json').exists())
    def test_target_conflict(self):
        p=m.plan(self.root,'old.json','new.json');(self.root/'new.json').write_text('keep')
        with self.assertRaises(ValueError):m.apply(self.root,p)
        self.assertEqual('keep',(self.root/'new.json').read_text())
    def test_advanced_target_not_deleted(self):
        r=m.apply(self.root,m.plan(self.root,'old.json','new.json'));(self.root/'new.json').write_text('advanced')
        with self.assertRaises(ValueError):m.rollback(self.root,r)
        self.assertTrue((self.root/'new.json').exists())
    def test_escape(self):
        with self.assertRaises(ValueError):m.plan(self.root,'../secret','new.json')
    def test_sentinel_required(self):
        (self.root/'CONTROLLED_SAMPLES_ONLY').unlink()
        with self.assertRaises(ValueError):m.root_at(self.root)
    def test_repeat_apply_fails_closed(self):
        p=m.plan(self.root,'old.json','new.json');m.apply(self.root,p)
        with self.assertRaises(ValueError):m.apply(self.root,p)
    def test_wrong_family(self):
        (self.root/'old.json').write_text('{"schema":2,"campaign":"other"}')
        with self.assertRaises(ValueError):m.plan(self.root,'old.json','new.json')
    def test_interrupted_temp_preserved(self):
        p=m.plan(self.root,'old.json','new.json');(self.root/'new.json.migration.tmp').write_text('partial')
        with self.assertRaises(ValueError):m.apply(self.root,p)
        self.assertFalse((self.root/'new.json').exists());self.assertEqual('partial',(self.root/'new.json.migration.tmp').read_text())
    def test_forged_rollback_cannot_remove_original(self):
        r=m.apply(self.root,m.plan(self.root,'old.json','new.json'));r['target']='old.json'
        with self.assertRaises(ValueError):m.rollback(self.root,r)
        self.assertTrue((self.root/'old.json').exists())
if __name__=='__main__':unittest.main()
