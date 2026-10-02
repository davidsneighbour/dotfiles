"""Verify scoped removal without touching the installed crontab."""
import importlib.util
import pathlib
import sys
import types
import unittest

sys.modules['dotbot'] = types.SimpleNamespace(Plugin=object)
spec = importlib.util.spec_from_file_location('cron_plugin', pathlib.Path(__file__).parents[1] / 'plugins' / 'crontab.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class CrontabTest(unittest.TestCase):
    def test_absent_entry_preserves_unrelated_jobs(self):
        plugin = module.Crontab()
        plugin._log = types.SimpleNamespace(lowinfo=lambda message: None, info=lambda message: None, error=lambda message: None)
        old = {'cron': '0 8 * * *', 'command': '/path/old-reporter', 'comment': 'old report'}
        new = {'id': 'archive-daily', 'cron': '0 8 * * *', 'command': '/path/new-reporter', 'comment': 'new report'}
        unrelated = '*/2 * * * * /path/unrelated # other job'
        installed = [unrelated, plugin._format_row(old)]
        plugin._read_current_cron_rows = lambda: installed.copy()
        def install(rows):
            installed[:] = rows
            return 0
        plugin._install_cron_rows = install
        self.assertTrue(plugin.handle('crontab', [{**old, 'state': 'absent'}, new]))
        self.assertEqual(installed, [unrelated, plugin._format_row(new)])
        changed = {**new, 'command': '/path/replacement-runtime'}
        self.assertTrue(plugin.handle('crontab', [changed]))
        self.assertEqual(installed, [unrelated, plugin._format_row(changed)])
        self.assertTrue(plugin.handle('crontab', [{**old, 'state': 'absent'}, new]))
        self.assertEqual(installed, [unrelated, plugin._format_row(new)])

if __name__ == '__main__':
    unittest.main()
