In this dotfiles repository, clean up log files under `logs/` before CUT_OFF_DATE.

CUT_OFF_DATE may be given as `YYYY MM` or `YYYY MM DD`.
If only year/month is given, delete files before the first day of that month.
If a full date is given, delete files before that date.
The date is exclusionary in any case.

Safety rules:
- Read AGENTS.md first.
- Only inspect files under `logs/`.
- Never delete `*.lock` files.
- Only delete files whose basename contains an obvious `YYYYMMDD` date.
- Compare that filename date to CUT_OFF_DATE.
- Do not delete undated or ambiguous files based on mtime.
- Before deleting, count candidates and summarize large obvious dated groups as `folder > N date-named files`.
- Delete only the exact candidate set.
- After deleting, verify no date-named files older than the cutoff remain.
- List undated files with their modified timestamp as questionable naming-system follow-up items.
- Report "strange things" that might be bugs, misconfigurations, stray items that don't belong into `logs/`
