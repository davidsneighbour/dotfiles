# Repository-local configuration

Repositories may optionally define a configuration file at `.github/dnb.toml`.

Properties:

* File may exist or not
* Absence is **not an error**
* Consumers must treat missing values as `false`
* Empty strings are valid values
* Only zero-length strings are considered empty

## Access pattern

* Configuration keys use dot notation: `section.key`
* Consumers must rely on **exit codes**, not sentinel strings
* Literal `"false"` is a valid value and must not collide with "not found"

This design intentionally avoids JSON and complex schemas.
