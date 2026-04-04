# Review summary

## Main problems fixed or isolated

* Normalised public naming around `dnb_*`.
* Added compatibility wrappers for older `__dnb_*` and unprefixed names.
* Replaced the duplicate PATH helper situation with a single canonical implementation.
* Fixed the logging API direction by using `dnb_log <level> <message>` consistently.
* Replaced the old eval-based `execute` helper with `dnb_execute_lines`.
* Moved standalone behaviour into `bashrc/helpers`.
* Deprecated obsolete release helpers with explicit CLI warnings.
* Added a source-safe library contract in `_lib/README.md`.

## Notes

* `dnb_config_get` and `dnb_repo_config_get` were retained with minimal change because they were already useful and largely safe.
* Release helper implementations were not migrated because the requested direction was to deprecate them gracefully rather than modernise them further.
* Helper wrappers in `bashrc/helpers` intentionally keep logic thin and rely on `_lib` as the implementation layer.

## Next Steps

* go through 90-compat

## ToDo Checks

* _lib to lib renaming
* docs/bash-environment.md - rewrite _lib and add structural notes
* .github/instructions/verbosity.instructions.md - rewrite _lib and structural notes
