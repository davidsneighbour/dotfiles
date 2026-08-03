import hashlib
import subprocess
import tempfile

import dotbot


class Crontab(dotbot.Plugin):

    # Dotbot methods
    _comment = "#dotbot-crontab"
    _directive = "crontab"

    def can_handle(self, directive):
        return directive == self._directive

    def handle(self, directive, data):
        if directive != self._directive:
            self._log.error("We can't handle {}".format(directive))
            return False
        try:
            cronjob_rows = []
            unscoped_cronjob_rows = []
            cronjob_tokens = []
            legacy_cronjob_rows = []
            for entry in data:
                row = self._format_row(entry)
                unscoped_row = self._format_unscoped_row(entry)
                token = self._entry_token(entry)
                legacy_row = self._format_legacy_row(entry)
                self._log.lowinfo("Add {}".format(row))
                cronjob_rows.append(row)
                unscoped_cronjob_rows.append(unscoped_row)
                cronjob_tokens.append(token)
                legacy_cronjob_rows.append(legacy_row)
            self._sync_cron_file(
                cronjob_rows,
                unscoped_cronjob_rows,
                cronjob_tokens,
                legacy_cronjob_rows,
            )
            self._log.info("All cron have been sync")
            return True
        except ValueError as e:
            self._log.error(e)
            return False

    def _format_row(self, entry):
        comment = entry.get("comment")
        token = self._entry_token(entry)
        if comment:
            return "{} {} # {} {}".format(entry["cron"], entry["command"], comment, token)
        return "{} {} {}".format(entry["cron"], entry["command"], token)

    def _format_legacy_row(self, entry):
        return "{} {} {} {}".format(
            entry["cron"], entry["command"], "#", entry.get("comment", self._comment)
        )

    def _format_unscoped_row(self, entry):
        comment = entry.get("comment")
        if comment:
            return "{} {} # {} {}".format(entry["cron"], entry["command"], comment, self._comment)
        return "{} {} {}".format(entry["cron"], entry["command"], self._comment)

    def _entry_token(self, entry):
        identity = "{}\n{}".format(entry.get("comment", ""), entry["command"])
        digest = hashlib.sha256(identity.encode("utf-8")).hexdigest()[:12]
        return "{}:{}".format(self._comment, digest)

    def _sync_cron_file(self, rows, unscoped_rows, tokens, legacy_rows):
        current_rows = self._read_current_cron_rows()
        preserved_rows = self._preserve_user_rows(
            current_rows,
            rows,
            unscoped_rows,
            tokens,
            legacy_rows,
        )
        updated_rows = preserved_rows + rows
        backup_rows = list(current_rows)

        exit_code = self._install_cron_rows(updated_rows)
        if exit_code != 0:
            self._log.error("Failed to install updated crontab; restoring previous crontab")
            restore_code = self._install_cron_rows(backup_rows)
            if restore_code != 0:
                raise ValueError("Failed to restore previous crontab")
            raise ValueError("Failed to install updated crontab")

    def _read_current_cron_rows(self):
        result = subprocess.run(
            ["crontab", "-l"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        if result.returncode not in (0, 1):
            raise ValueError("Failed to read current crontab: {}".format(result.stderr.strip()))
        if result.returncode == 1 and result.stderr.strip() and "no crontab for" not in result.stderr:
            raise ValueError("Failed to read current crontab: {}".format(result.stderr.strip()))
        return result.stdout.splitlines()

    def _preserve_user_rows(self, current_rows, rows, unscoped_rows, tokens, legacy_rows):
        rows = set(rows)
        unscoped_rows = set(unscoped_rows)
        tokens = set(tokens)
        legacy_rows = set(legacy_rows)
        preserved_rows = []
        for row in current_rows:
            if row in rows:
                continue
            if row in unscoped_rows:
                continue
            if row in legacy_rows:
                continue
            if any(token in row for token in tokens):
                continue
            preserved_rows.append(row)
        return preserved_rows

    def _install_cron_rows(self, rows):
        with tempfile.NamedTemporaryFile("w", delete=True) as cron_file:
            for row in rows:
                cron_file.write("{}\n".format(row))
            cron_file.flush()
            return subprocess.call(["crontab", cron_file.name])
