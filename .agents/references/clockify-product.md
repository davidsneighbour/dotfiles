# Clockify client and project product decisions

* **Delete = archive.** Clockify rejects hard-deleting a client/project that has time entries against
  it. "Delete" in this tool's CLI and form always archives (`archived: true`) rather than calling a
  hard-delete endpoint.
* **Add/edit UI = modal dialog** in the web form, not an inline panel or a separate route. Saving
  closes the dialog and immediately selects the new/edited item in the underlying time-tracking form —
  no page reload.
* **Color picker = fixed swatch grid only** (no free-hex input in v1), matching "single user, don't
  overcomplicate."
* **CLI gets parity in the same pass**: `client`/`project` add/edit/(archive-as-)remove subcommands,
  sharing helper functions with the form's endpoints as described above.
* Hierarchy is top-down: clients have projects, projects have time entries. The "add project" flow
  must offer "add client" inline too (client can be created without leaving the project-creation step).
