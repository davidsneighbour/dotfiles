#!/usr/bin/python3
"""Save, apply, delete, and edit i3 workspace layouts.

A layout file is JSON with:

* `label`  — the name shown in Rofi.
* `icon`   — the workspace icon used when the layout is applied (empty: the
             fallback icon from workspaces.yaml).
* `layout` — i3 containers for `append_layout`. Windows are placeholders with
             `swallows` rules (class/instance regexes).
* `launch` — commands (argv lists) started after the placeholders exist. i3
             puts each new window into the first placeholder it matches.

See configs/session/i3/README.md, "Workspace layouts".
"""

from __future__ import annotations

import argparse
import json
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any

from workspaces import (
    DEFAULT_CONFIG,
    I3_SESSION_DIR,
    PromotedWindow,
    get_i3_tree,
    i3_msg,
    i3_quote,
    i3_result_error,
    i3_result_succeeded,
    is_switchable_window,
    load_config,
    load_window_icon_config,
    next_dynamic_workspace_number,
    window_icon_identity,
)


# Tracked in git on purpose: saved layouts are part of the dotfiles.
DEFAULT_LAYOUTS_DIR = I3_SESSION_DIR / "layouts"
ROFI_CONFIG = I3_SESSION_DIR / "rofi.rasi"
EDITOR = "subl"
NOTIFY_APP_NAME = "i3 layouts"
PRIVATE_USE_GLYPH = re.compile("[-]")


def notify(summary: str, body: str = "", *, error: bool = False) -> None:
    """Show a desktop notification; bindings have no visible stdout/stderr."""
    print(f"{summary}: {body}" if body else summary, file=sys.stderr if error else sys.stdout)
    if shutil.which("notify-send") is None:
        return
    subprocess.run(
        [
            "notify-send",
            "--app-name",
            NOTIFY_APP_NAME,
            "--urgency",
            "critical" if error else "normal",
            summary,
            body,
        ],
        check=False,
    )


# ---------------------------------------------------------------------------
# Rofi
# ---------------------------------------------------------------------------


def rofi(prompt: str, entries: list[str], *, message: str = "") -> int | None:
    """Return the index of the selected entry, or None when cancelled."""
    command = ["rofi", "-dmenu", "-i", "-no-custom", "-format", "i", "-p", prompt]
    if ROFI_CONFIG.is_file():
        command += ["-config", str(ROFI_CONFIG)]
    if message:
        command += ["-mesg", message]
    result = subprocess.run(
        command,
        input="\n".join(entries),
        check=False,
        stdout=subprocess.PIPE,
        text=True,
    )
    selected = result.stdout.strip()
    if result.returncode != 0 or not selected.isdigit():
        return None
    index = int(selected)
    return index if 0 <= index < len(entries) else None


def rofi_text(prompt: str) -> str | None:
    """Ask for free text (no list). Return None when cancelled."""
    command = [
        "rofi",
        "-dmenu",
        "-p",
        prompt,
        "-theme-str",
        "listview { enabled: false; }",
    ]
    if ROFI_CONFIG.is_file():
        command += ["-config", str(ROFI_CONFIG)]
    result = subprocess.run(
        command, input="", check=False, stdout=subprocess.PIPE, text=True
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def confirm(prompt: str, yes_label: str) -> bool:
    # "No" is first, so pressing Enter without choosing does nothing.
    return rofi(prompt, ["No", yes_label]) == 1


# ---------------------------------------------------------------------------
# Layout files
# ---------------------------------------------------------------------------


def slugify(label: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", label.casefold()).strip("-")


def layout_files(layouts_dir: Path) -> list[Path]:
    if not layouts_dir.is_dir():
        return []
    return sorted(layouts_dir.glob("*.json"))


def read_layout(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        loaded = json.load(handle)
    if not isinstance(loaded, dict):
        raise ValueError("top level must be a JSON object")
    return loaded


def layout_label(path: Path) -> str:
    try:
        label = read_layout(path).get("label")
    except (OSError, ValueError) as error:
        return f"{path.stem} (invalid: {error})"
    return str(label) if isinstance(label, str) and label.strip() else path.stem


def write_layout(path: Path, data: dict[str, Any]) -> None:
    text = json.dumps(data, indent=2, ensure_ascii=False)
    # Write icon glyphs as \uXXXX escapes, as workspaces.yaml does: editors
    # and shells mangle private-use glyphs easily.
    text = PRIVATE_USE_GLYPH.sub(lambda match: f"\\u{ord(match.group()):04x}", text)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f"{text}\n", encoding="utf-8")


def pick_layout(layouts_dir: Path, prompt: str, name: str | None) -> Path | None:
    """Return the layout file named by --layout, or the one picked in Rofi."""
    if name:
        path = layouts_dir / f"{slugify(name)}.json"
        if not path.is_file():
            notify("Layout not found", str(path), error=True)
            return None
        return path

    files = layout_files(layouts_dir)
    if not files:
        notify("No saved layouts", f"Save one first. Folder: {layouts_dir}", error=True)
        return None

    labelled = sorted(((layout_label(path), path) for path in files), key=lambda item: item[0].casefold())
    index = rofi(prompt, [label for label, _path in labelled])
    return None if index is None else labelled[index][1]


def open_in_editor(path: Path) -> int:
    if shutil.which(EDITOR) is None:
        notify("Cannot open layout", f"'{EDITOR}' not found in PATH", error=True)
        return 1
    subprocess.Popen(
        [EDITOR, str(path)],
        start_new_session=True,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return 0


# ---------------------------------------------------------------------------
# Save: i3 tree -> layout
# ---------------------------------------------------------------------------


def contains_focus(node: dict[str, Any]) -> bool:
    if node.get("focused") is True:
        return True
    return any(
        isinstance(child, dict) and contains_focus(child)
        for key in ("nodes", "floating_nodes")
        for child in node.get(key, [])
    )


def focused_workspace(node: dict[str, Any]) -> dict[str, Any] | None:
    if node.get("type") == "workspace":
        return node if contains_focus(node) else None
    for key in ("nodes", "floating_nodes"):
        for child in node.get(key, []):
            if isinstance(child, dict):
                match = focused_workspace(child)
                if match is not None:
                    return match
    return None


def window_pid(window_id: int) -> int | None:
    if shutil.which("xprop") is None:
        return None
    result = subprocess.run(
        ["xprop", "-id", str(window_id), "_NET_WM_PID"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    match = re.search(r"=\s*(\d+)", result.stdout)
    return int(match.group(1)) if match else None


def launch_entry(node: dict[str, Any]) -> dict[str, Any]:
    properties = node.get("window_properties", {})
    window_class = str(properties.get("class", "")) if isinstance(properties, dict) else ""
    instance = str(properties.get("instance", "")) if isinstance(properties, dict) else ""
    entry: dict[str, Any] = {
        "window": f"{window_class}/{instance}: {node.get('name', '')}",
        "command": [],
    }

    window_id = node.get("window")
    pid = window_pid(window_id) if isinstance(window_id, int) else None
    if pid is None:
        entry["note"] = "No process found for this window. Add the command by hand."
        return entry

    try:
        raw = Path(f"/proc/{pid}/cmdline").read_bytes()
        command = [part.decode("utf-8", "replace") for part in raw.split(b"\0") if part]
    except OSError as error:
        entry["note"] = f"Could not read the command of process {pid}: {error}"
        return entry

    # Electron programs (VS Code, Obsidian, ...) rewrite their process title
    # into one space-separated string. Split it back into argv.
    if len(command) == 1 and " " in command[0] and not Path(command[0]).exists():
        command = shlex.split(command[0])
    entry["command"] = command

    try:
        entry["cwd"] = str(Path(f"/proc/{pid}/cwd").resolve(strict=True))
    except OSError:
        pass  # cwd is optional; apply falls back to $HOME.
    return entry


def window_swallow(node: dict[str, Any]) -> dict[str, str]:
    properties = node.get("window_properties", {})
    swallow: dict[str, str] = {}
    if isinstance(properties, dict):
        for key in ("class", "instance"):
            value = properties.get(key)
            if isinstance(value, str) and value:
                swallow[key] = f"^{re.escape(value)}$"
    return swallow


def normalise_percent(nodes: list[dict[str, Any]]) -> None:
    """Make the sizes of kept siblings add up to 1 after windows were dropped."""
    percents = [node.get("percent") for node in nodes]
    if not all(isinstance(value, (int, float)) and value > 0 for value in percents):
        for node in nodes:
            node.pop("percent", None)
        return
    total = sum(float(value) for value in percents if isinstance(value, (int, float)))
    for node in nodes:
        node["percent"] = round(float(node["percent"]) / total, 4)


def layout_node(
    node: dict[str, Any], windows: list[dict[str, Any]]
) -> dict[str, Any] | None:
    """Convert a tiled i3 node to an append_layout node. Collect its windows."""
    if node.get("window") is not None:
        swallow = window_swallow(node)
        if not is_switchable_window(node) or not swallow:
            return None
        windows.append(node)
        leaf: dict[str, Any] = {
            "type": "con",
            "name": str(node.get("name", "")),
            "swallows": [swallow],
        }
        for key in ("percent", "border", "current_border_width"):
            if node.get(key) is not None:
                leaf[key] = node[key]
        return leaf

    children = [
        converted
        for child in node.get("nodes", [])
        if isinstance(child, dict)
        for converted in [layout_node(child, windows)]
        if converted is not None
    ]
    if not children:
        return None
    if len(children) == 1:
        only = children[0]
        if node.get("percent") is not None:
            only["percent"] = node["percent"]
        return only

    normalise_percent(children)
    container: dict[str, Any] = {
        "type": "con",
        "layout": node.get("layout", "splith"),
        "nodes": children,
    }
    if node.get("percent") is not None:
        container["percent"] = node["percent"]
    return container


def floating_layout_node(
    node: dict[str, Any], windows: list[dict[str, Any]]
) -> dict[str, Any] | None:
    children = [
        converted
        for child in node.get("nodes", [])
        if isinstance(child, dict)
        for converted in [layout_node(child, windows)]
        if converted is not None
    ]
    if not children:
        return None
    for child in children:
        child.pop("percent", None)
    floating: dict[str, Any] = {"type": "floating_con", "floating": "user_on", "nodes": children}
    if isinstance(node.get("rect"), dict):
        floating["rect"] = node["rect"]
    return floating


def workspace_layout(workspace: dict[str, Any]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Return the top-level layout nodes and the window nodes in tree order."""
    windows: list[dict[str, Any]] = []
    tiled = [
        converted
        for child in workspace.get("nodes", [])
        if isinstance(child, dict)
        for converted in [layout_node(child, windows)]
        if converted is not None
    ]

    top: list[dict[str, Any]] = []
    if len(tiled) == 1:
        tiled[0].pop("percent", None)
        top.append(tiled[0])
    elif tiled:
        # Keep the workspace's own split direction (or tabbed/stacked) by
        # wrapping its children in one container with that layout.
        normalise_percent(tiled)
        top.append({"type": "con", "layout": workspace.get("layout", "splith"), "nodes": tiled})

    for child in workspace.get("floating_nodes", []):
        if isinstance(child, dict):
            floating = floating_layout_node(child, windows)
            if floating is not None:
                top.append(floating)

    return top, windows


def command_save(args: argparse.Namespace) -> int:
    workspace = focused_workspace(get_i3_tree())
    if workspace is None:
        notify("Cannot save layout", "No focused workspace found", error=True)
        return 1

    layout, windows = workspace_layout(workspace)
    if not windows:
        notify("Cannot save layout", "The current workspace has no windows", error=True)
        return 1

    label = args.label if args.label is not None else rofi_text("Layout label")
    if label is None:
        return 0  # Cancelled in Rofi.
    label = label.strip()
    slug = slugify(label)
    if not slug:
        notify("Cannot save layout", "The label must contain a letter or a digit", error=True)
        return 1

    path = args.layouts_dir / f"{slug}.json"
    if path.exists() and not args.yes and not confirm(
        f"Layout '{label}' exists", f"Yes, replace {path.name}"
    ):
        return 0

    icon_config = load_window_icon_config(load_config(args.config))
    first = windows[0].get("window_properties", {})
    _slug, icon = window_icon_identity(
        icon_config,
        PromotedWindow(
            con_id=0,
            window_class=str(first.get("class", "")) if isinstance(first, dict) else "",
            instance=str(first.get("instance", "")) if isinstance(first, dict) else "",
            title="",
        ),
    )

    write_layout(
        path,
        {
            "label": label,
            "icon": icon,
            "saved": datetime.now().isoformat(timespec="seconds"),
            "launch": [launch_entry(window) for window in windows],
            "layout": layout,
        },
    )
    notify("Layout saved", f"{label}: {len(windows)} window(s) in {path}")
    return 0 if args.no_edit else open_in_editor(path)


# ---------------------------------------------------------------------------
# Apply, delete, edit
# ---------------------------------------------------------------------------


def launch_commands(data: dict[str, Any]) -> list[tuple[list[str], str]]:
    launch = data.get("launch", [])
    if not isinstance(launch, list):
        raise ValueError("'launch' must be a list")
    commands: list[tuple[list[str], str]] = []
    for position, entry in enumerate(launch, start=1):
        if not isinstance(entry, dict):
            raise ValueError(f"launch entry {position} must be an object")
        command = entry.get("command", [])
        if not isinstance(command, list) or not all(isinstance(part, str) for part in command):
            raise ValueError(f"launch entry {position}: 'command' must be a list of strings")
        if not command:
            continue  # Empty command: the placeholder stays until a window matches.
        cwd = entry.get("cwd")
        directory = cwd if isinstance(cwd, str) and Path(cwd).is_dir() else str(Path.home())
        commands.append((command, directory))
    return commands


def command_apply(args: argparse.Namespace) -> int:
    path = pick_layout(args.layouts_dir, "Apply layout", args.layout)
    if path is None:
        return 0 if not args.layout else 1

    try:
        data = read_layout(path)
        layout = data.get("layout")
        if not isinstance(layout, list) or not all(isinstance(node, dict) for node in layout):
            raise ValueError("'layout' must be a list of objects")
        commands = launch_commands(data)
    except (OSError, ValueError) as error:
        notify("Cannot apply layout", f"{path.name}: {error}", error=True)
        return 1

    icon = data.get("icon")
    if not isinstance(icon, str) or not icon.strip():
        icon = load_window_icon_config(load_config(args.config)).fallback_icon
    workspace_name = f"{next_dynamic_workspace_number()}:{icon.strip()}"

    # append_layout reads one JSON object after another, not a JSON array.
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", suffix=".json", prefix="i3-layout-", delete=False
    ) as handle:
        handle.write("\n".join(json.dumps(node) for node in layout))
        layout_file = Path(handle.name)
    try:
        result = i3_msg(
            f"workspace number {i3_quote(workspace_name)}; append_layout {i3_quote(str(layout_file))}"
        )
    finally:
        layout_file.unlink(missing_ok=True)

    if not i3_result_succeeded(result):
        notify("Cannot apply layout", i3_result_error(result) or "i3 refused the layout", error=True)
        return 1

    failed: list[str] = []
    for command, directory in commands:
        try:
            subprocess.Popen(
                command,
                cwd=directory,
                start_new_session=True,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except OSError as error:
            failed.append(f"{command[0]}: {error}")

    if failed:
        notify("Some layout programs did not start", "\n".join(failed), error=True)
        return 1
    if args.verbose:
        print(f"Applied {path.name} on workspace {workspace_name}, started {len(commands)} program(s)")
    return 0


def command_delete(args: argparse.Namespace) -> int:
    path = pick_layout(args.layouts_dir, "Delete layout", args.layout)
    if path is None:
        return 0 if not args.layout else 1

    label = layout_label(path)
    if not args.yes and not confirm(f"Delete '{label}'?", f"Yes, delete {path.name}"):
        return 0

    try:
        path.unlink()
    except OSError as error:
        notify("Cannot delete layout", f"{path}: {error}", error=True)
        return 1
    notify("Layout deleted", label)
    return 0


def command_edit(args: argparse.Namespace) -> int:
    path = pick_layout(args.layouts_dir, "Edit layout", args.layout)
    if path is None:
        return 0 if not args.layout else 1
    return open_in_editor(path)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Save the current i3 workspace as a layout, and apply, delete, or edit saved layouts.",
        epilog="Example: layouts.py save --label 'Writing' --no-edit",
    )
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG, help="workspaces.yaml (icons)")
    parser.add_argument(
        "--layouts-dir",
        type=Path,
        default=DEFAULT_LAYOUTS_DIR,
        help=f"folder with the layout files (default: {DEFAULT_LAYOUTS_DIR})",
    )
    parser.add_argument("--verbose", action="store_true", help="print more about what happens")
    subparsers = parser.add_subparsers(dest="command", required=True)

    save = subparsers.add_parser("save", help="save the focused workspace, then open the file in subl")
    save.add_argument("--label", default=None, help="layout label (default: ask in Rofi)")
    save.add_argument("--yes", action="store_true", help="replace an existing layout without asking")
    save.add_argument("--no-edit", action="store_true", help="do not open the saved file in subl")
    save.set_defaults(func=command_save)

    for name, func, help_text in (
        ("apply", command_apply, "start a new workspace with a saved layout"),
        ("delete", command_delete, "delete a saved layout (asks for confirmation)"),
        ("edit", command_edit, "open a saved layout in subl"),
    ):
        sub = subparsers.add_parser(name, help=help_text)
        sub.add_argument("--layout", default=None, help="layout label or file name (default: pick in Rofi)")
        if name == "delete":
            sub.add_argument("--yes", action="store_true", help="delete without asking")
        sub.set_defaults(func=func)

    return parser


def main() -> int:
    args = build_parser().parse_args()
    args.layouts_dir = args.layouts_dir.expanduser()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
