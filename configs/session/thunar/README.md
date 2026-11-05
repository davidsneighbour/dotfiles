# Thunar configuration

Dotbot links this folder to `~/.config/Thunar` (see [config.yaml](../../dotbot/config.yaml)).

| File | Purpose |
| --- | --- |
| `uca.xml` | Custom actions shown in the Thunar context menu. |
| `accels.scm` | Keyboard shortcuts, including the shortcuts for the custom actions in `uca.xml`. |

## Accelerator map header

Thunar rewrites `accels.scm` when it exits. The first comment line says `Thunar` or `thunar`, depending on how Thunar was started. To stop this from showing as a change in Git, [`.gitattributes`](../../../.gitattributes) assigns the file to the `thunar-accels` clean filter, which normalises the header to `Thunar`. Real shortcut changes still show as changes.

Git filter commands are local Git configuration and are not part of the repository. The default Dotbot profile (`dotfiles`) sets the filter up. Without it, Git compares the file unchanged and the header flip shows again. To set it up by hand:

```bash
git config --local filter.thunar-accels.clean \
  "sed '1s/^; thunar GtkAccelMap/; Thunar GtkAccelMap/'"
```
