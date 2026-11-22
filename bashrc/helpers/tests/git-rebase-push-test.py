"""Exercise rebase and publication against isolated local Git repositories."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


HELPER = Path(__file__).resolve().parents[1] / "git-rebase-push"


class RebasePushTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = dict(os.environ, HOME=str(self.root), GIT_CONFIG_NOSYSTEM="1",
                        GIT_CONFIG_GLOBAL="/dev/null", GIT_AUTHOR_NAME="Test",
                        GIT_AUTHOR_EMAIL="test@example.invalid",
                        GIT_COMMITTER_NAME="Test",
                        GIT_COMMITTER_EMAIL="test@example.invalid",
                        DNB_UI_FORMAT="plain")
        self.remote = self.root / "remote.git"
        self.repo = self.root / "work"
        self.command("git", "init", "--bare", str(self.remote), cwd=self.root)
        self.command("git", "init", "-b", "main", str(self.repo), cwd=self.root)
        self.commit("base", "base")
        self.git("remote", "add", "origin", str(self.remote))
        self.git("push", "origin", "main")
        self.git("switch", "-c", "feature")
        self.commit("feature", "feature")
        self.git("push", "origin", "feature")
        self.old_remote = self.git("rev-parse", "feature").stdout.strip()
        self.git("switch", "main")
        self.commit("new-base", "new base")
        self.git("push", "origin", "main")
        self.git("switch", "feature")

    def command(self, *args, cwd=None, check=True):
        return subprocess.run(args, cwd=cwd or self.repo, env=self.env,
                              text=True, capture_output=True, check=check)

    def git(self, *args):
        return self.command("git", *args)

    def commit(self, name, content):
        (self.repo / name).write_text(content)
        self.git("add", name)
        self.git("commit", "-m", "test change")

    def invoke(self, *args):
        return self.command(str(HELPER), *args, check=False)

    def remote_tip(self):
        return self.git("ls-remote", "origin", "refs/heads/feature").stdout.split()[0]

    def test_defaults_rebase_check_and_publish(self):
        result = self.invoke("--", "git", "merge-base", "--is-ancestor", "main", "HEAD")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.remote_tip(), self.git("rev-parse", "HEAD").stdout.strip())
        self.assertNotEqual(self.remote_tip(), self.old_remote)

    def test_failed_checks_do_not_push(self):
        result = self.invoke("--", "false")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.remote_tip(), self.old_remote)

    def test_default_npm_checks(self):
        self.commit("package.json", json.dumps({"scripts": {
            "check": "git merge-base --is-ancestor main HEAD"}}))
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("git merge-base --is-ancestor main HEAD", result.stderr)
        self.assertEqual(self.remote_tip(), self.git("rev-parse", "HEAD").stdout.strip())

    def test_default_npm_check_failure_with_options_does_not_push(self):
        self.commit("package.json", json.dumps({"scripts": {"check": "exit 1"}}))
        result = self.invoke("--base", "main")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("npm failed", result.stderr)
        self.assertEqual(self.remote_tip(), self.old_remote)

    def test_conflict_does_not_run_checks_or_push(self):
        self.git("switch", "main")
        self.commit("base", "main change")
        self.git("push", "origin", "main")
        self.git("switch", "feature")
        self.commit("base", "feature change")
        result = self.invoke("--", "touch", "checks-ran")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.repo / "checks-ran").exists())
        self.assertEqual(self.remote_tip(), self.old_remote)
        self.assertIn("git rebase --abort", result.stderr)

    def test_checks_that_modify_files_do_not_push(self):
        result = self.invoke("--", "touch", "generated")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.remote_tip(), self.old_remote)

    def test_dirty_worktree_does_not_rebase(self):
        (self.repo / "untracked").write_text("keep")
        result = self.invoke("--", "true")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.git("rev-parse", "HEAD").stdout.strip(), self.old_remote)

    def test_named_branch_and_remote(self):
        self.git("remote", "rename", "origin", "upstream")
        self.git("branch", "development", "main")
        self.git("push", "upstream", "development")
        self.git("switch", "main")
        result = self.invoke("--base", "development", "--remote", "upstream",
                             "--branch", "feature", "--", "true")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git("branch", "--show-current").stdout.strip(), "feature")

    def test_concurrent_remote_update_rejects_push(self):
        # The check command simulates a second writer changing the remote ref.
        result = self.invoke("--", "git", "--git-dir", str(self.remote),
                             "update-ref", "refs/heads/feature",
                             self.git("rev-parse", "main").stdout.strip())
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.remote_tip(), self.git("rev-parse", "main").stdout.strip())

    def test_remote_only_commits_are_preserved(self):
        self.git("--git-dir", str(self.remote), "update-ref", "refs/heads/feature",
                 self.git("rev-parse", "main").stdout.strip())
        result = self.invoke("--", "true")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("commits missing locally", result.stderr)
        self.assertEqual(self.git("rev-parse", "HEAD").stdout.strip(), self.old_remote)

    def test_help_and_empty_override_have_no_git_effects(self):
        result = self.command(str(HELPER), "--help", cwd=self.root, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Options:", result.stdout)
        self.assertFalse((self.root / ".logs").exists())
        result = self.invoke("--base", "main", "--")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.remote_tip(), self.old_remote)


if __name__ == "__main__":
    unittest.main()
