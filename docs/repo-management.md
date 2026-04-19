## Commit message conventions

This repository uses Conventional Commits.

### Format

```text
type(scope): short summary
```

Examples:

```text
chore(vscode): update workspace settings
chore(vscode): add recommended extensions
feat(xfce): add new desktop workspace
fix(xfce): rename desktop workspace labels
docs(vscode): document workspace setup
docs(xfce): document desktop workspace layout
```

### Types

Use the commit type to describe the kind of change:

* `feat`: introduces a new feature or capability
* `fix`: fixes incorrect behaviour or a bug
* `chore`: maintenance, housekeeping, non-feature configuration updates
* `build`: build system, tooling pipeline, dependency or release process changes
* `docs`: documentation only
* `refactor`: code changes without behaviour change
* `test`: tests added or updated

### Scopes

Use the scope to describe the affected system or domain.

#### Editor and repository configuration

Use `vscode` for changes related to VS Code or repository editor setup, for example:

* `.vscode/` settings
* workspace files
* recommended extensions
* launch configurations
* tasks
* editor integration files

Examples:

```text
chore(vscode): update workspace settings
chore(vscode): add recommended extensions
```

#### Desktop workspaces

Use `xfce` for changes related to desktop workspaces or XFCE desktop configuration, for example:

* workspace count
* workspace names
* panel or window-manager integration
* desktop switching setup

Examples:

```text
feat(xfce): add new desktop workspace
fix(xfce): rename workspace labels
```

### Important rule

Do not use generic scopes such as `config`, `settings`, or `workspace` when a more specific scope exists.

Prefer this:

```text
chore(vscode): update workspace settings
fix(xfce): rename workspace labels
```

Avoid this:

```text
chore(config): update vscode workspace settings
fix(workspace): rename workspace
```

### Writing subjects

Keep the subject line short, specific, and action-oriented.

Good:

```text
chore(vscode): add recommended extensions
feat(xfce): add workspace 4
fix(xfce): rename workspace labels
```

Less useful:

```text
chore(config): update stuff
fix(workspace): fix workspace issue
```

### When the word "workspace" appears

The word "workspace" is ambiguous in this repository. Always make the scope explicit:

* `vscode` = VS Code workspace/editor/repository setup
* `xfce` = desktop workspace/window manager setup

If needed, repeat the full phrase in the subject for clarity:

```text
chore(vscode): update VS Code workspace settings
feat(xfce): add desktop workspace 4
fix(xfce): rename desktop workspace labels
```
