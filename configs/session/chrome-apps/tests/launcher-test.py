"""Exercise the real launcher with isolated configuration and a fake Chrome."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

LAUNCHER = Path(__file__).resolve().parents[1] / "bin/chrome-app"


class LauncherTest(unittest.TestCase):
    def test_profile_and_arguments(self):
        with tempfile.TemporaryDirectory(prefix="chrome-app-test-") as temporary:
            root = Path(temporary)
            config = root / "config/chrome-apps/apps"
            config.mkdir(parents=True)
            capture = root / "arguments.json"
            chrome = root / "fake-chrome"
            chrome.write_text(
                "#!/usr/bin/python3\n"
                "import json, os, sys\n"
                "with open(os.environ['CHROME_APP_CAPTURE'], 'w') as output:\n"
                "    json.dump(sys.argv[1:], output)\n"
            )
            chrome.chmod(0o755)
            wmctrl = root / "wmctrl"
            wmctrl.write_text(
                "#!/usr/bin/python3\n"
                "import os, sys\n"
                "from pathlib import Path\n"
                "if sys.argv[1:] == ['-lx']:\n"
                "    print(os.environ.get('CHROME_APP_WINDOWS', ''))\n"
                "else:\n"
                "    Path(os.environ['CHROME_APP_FOCUS']).write_text(' '.join(sys.argv[1:]))\n"
            )
            wmctrl.chmod(0o755)
            definition = LAUNCHER.parents[1] / "apps/whatsapp.conf"
            (config / "whatsapp.conf").write_text(
                definition.read_text() + f'CHROME_BINARY="{chrome}"\n'
            )
            environment = dict(os.environ, XDG_CONFIG_HOME=str(root / "config"),
                               XDG_DATA_HOME=str(root / "data"),
                               CHROME_APP_CAPTURE=str(capture),
                               CHROME_APP_FOCUS=str(root / "focus"),
                               PATH=str(root) + os.pathsep + os.environ["PATH"],
                               CHROME_APP_WINDOWS="")
            result = subprocess.run([str(LAUNCHER), "--inspect", "whatsapp"],
                                    env=environment, capture_output=True, text=True, check=True)
            profile = root / "data/chrome-apps/whatsapp"
            self.assertIn(str(profile), result.stdout)
            self.assertFalse(profile.exists())
            subprocess.run([str(LAUNCHER), "--app", "whatsapp"], env=environment, check=True)
            self.assertEqual(json.loads(capture.read_text()), [
                f"--user-data-dir={profile}", "--class=dnb-whatsapp",
                "--app=https://web.whatsapp.com/", "--no-first-run",
                "--no-default-browser-check",
            ])
            self.assertTrue(profile.is_dir())
            capture.unlink()
            environment["CHROME_APP_WINDOWS"] = (
                "0x123 11 web.whatsapp.com.dnb-whatsapp host WhatsApp\n"
                "0x456 12 web.whatsapp.com.dnb-whatsapp host WhatsApp"
            )
            subprocess.run([str(LAUNCHER), "--app", "whatsapp"], env=environment, check=True)
            self.assertFalse(capture.exists(), "A repeat launch must not start Chrome")
            self.assertEqual((root / "focus").read_text(), "-ia 0x123")
            rejected = subprocess.run([str(LAUNCHER), "--app", "../whatsapp"],
                                      env=environment, capture_output=True, text=True)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("invalid app identifier", rejected.stderr)


if __name__ == "__main__":
    unittest.main()
