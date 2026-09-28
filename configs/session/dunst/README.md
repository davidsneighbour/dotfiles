# Dunst

Configuration for the dunst notification daemon. Dotbot links this folder to `~/.config/dunst` (see `configs/dotbot/config.yaml`).

After you change `dunstrc`, run `dunstctl reload`. Check for config warnings with `journalctl --user -u dunst`.

Middle-click on a notification runs its action. `configs/session/storage/gdrive-mounts.sh` uses this for its "Re-authorise" action. Keep `mouse_middle_click = do_action, close_current` unless you change that script too.

How dunst starts and how it relates to the i3 session is documented in the "Notifications" section of [SESSION.md](../../../SESSION.md).
