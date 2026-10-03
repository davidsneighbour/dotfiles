#!/usr/bin/python3

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse

import yaml


WORKSPACES_DIR = Path(__file__).resolve().parent
I3_SESSION_DIR = WORKSPACES_DIR.parent
REPO_SESSION_DIR = I3_SESSION_DIR.parent
DEFAULT_CONFIG = WORKSPACES_DIR / "workspaces.yaml"
DEFAULT_I3_INCLUDE = I3_SESSION_DIR / "configs" / "workspaces.conf"
DEFAULT_POLYBAR_INCLUDE = (
    REPO_SESSION_DIR / "polybar" / "configs" / "07-module-i3.ini"
)
DEFAULT_ROFI_CONFIG = REPO_SESSION_DIR / "rofi" / "config.alt-tab-switcher.rasi"
DEFAULT_WINDOW_ICON = ""
DEFAULT_WINDOW_SLUG = "window"
RESERVED_DYNAMIC_WORKSPACE_NUMBERS = {90}
# How long `set-workspace-icon` waits for the launched program's first window.
WINDOW_ICON_WAIT_SECONDS = 15.0
WINDOW_ICON_POLL_SECONDS = 0.25


@dataclass(frozen=True)
class Workspace:
    key: int
    name: str
    icon: str

    @property
    def i3_name(self) -> str:
        return f"{self.key}:{self.icon}"


@dataclass(frozen=True)
class DynamicApplication:
    name: str
    icon: str
    workspace_prefix: str
    command: list[str]


@dataclass(frozen=True)
class WindowIconRule:
    window_class: str
    instance: str
    slug: str
    icon: str


@dataclass(frozen=True)
class WindowIconConfig:
    fallback_icon: str
    rules: list[WindowIconRule]


@dataclass(frozen=True)
class PromotedWindow:
    con_id: int
    window_class: str
    instance: str
    title: str


def load_config(config_path: Path) -> dict[str, Any]:
    with config_path.open("r", encoding="utf-8") as handle:
        loaded = yaml.safe_load(handle) or {}

    if not isinstance(loaded, dict):
        raise ValueError(f"{config_path} must contain a YAML object")

    return loaded


def load_workspaces(config: dict[str, Any]) -> list[Workspace]:
    raw_workspaces = config.get("workspaces", [])
    if not isinstance(raw_workspaces, list):
        raise ValueError("workspaces must be a list")

    workspaces: list[Workspace] = []
    for raw_workspace in raw_workspaces:
        if not isinstance(raw_workspace, dict):
            raise ValueError("each workspace must be an object")
        workspaces.append(
            Workspace(
                key=int(raw_workspace["key"]),
                name=str(raw_workspace["name"]),
                icon=str(raw_workspace["icon"]),
            )
        )

    return sorted(workspaces, key=lambda workspace: workspace.key)


def load_dynamic_applications(config: dict[str, Any]) -> dict[str, DynamicApplication]:
    raw_dynamic = config.get("dynamic", {})
    if not isinstance(raw_dynamic, dict):
        raise ValueError("dynamic must be an object")

    applications: dict[str, DynamicApplication] = {}
    for name, raw_application in raw_dynamic.items():
        if not isinstance(raw_application, dict):
            raise ValueError(f"dynamic.{name} must be an object")
        raw_command = raw_application.get("command", [])
        if not isinstance(raw_command, list) or not all(
            isinstance(part, str) for part in raw_command
        ):
            raise ValueError(f"dynamic.{name}.command must be a string list")
        applications[str(name)] = DynamicApplication(
            name=str(name),
            icon=str(raw_application["icon"]),
            workspace_prefix=str(raw_application["workspace_prefix"]),
            command=raw_command,
        )

    return applications


def load_window_icon_config(config: dict[str, Any]) -> WindowIconConfig:
    if "promote" in config:
        raise ValueError("promote: was renamed to window_icons: in workspaces.yaml")

    raw_icons = config.get("window_icons", {})
    if raw_icons is None:
        raw_icons = {}
    if not isinstance(raw_icons, dict):
        raise ValueError("window_icons must be an object")

    fallback_icon = str(raw_icons.get("fallback", DEFAULT_WINDOW_ICON)).strip()

    raw_rules = raw_icons.get("rules", [])
    if not isinstance(raw_rules, list):
        raise ValueError("window_icons.rules must be a list")

    rules: list[WindowIconRule] = []
    for raw_rule in raw_rules:
        if not isinstance(raw_rule, dict):
            raise ValueError("each window_icons.rules entry must be an object")

        window_class = str(raw_rule.get("class", "")).strip()
        instance = str(raw_rule.get("instance", "")).strip()
        slug = str(raw_rule.get("slug", "")).strip()
        icon = str(raw_rule.get("icon", "")).strip()

        if not window_class and not instance:
            raise ValueError("each window_icons.rules entry must set class or instance")
        if not icon:
            raise ValueError("each window_icons.rules entry must set icon")

        rules.append(
            WindowIconRule(
                window_class=window_class,
                instance=instance,
                slug=slug,
                icon=icon,
            )
        )

    return WindowIconConfig(
        fallback_icon=fallback_icon or DEFAULT_WINDOW_ICON,
        rules=rules,
    )


def generate_i3_config(workspaces: list[Workspace]) -> str:
    lines = [
        "################################################################################",
        "# Generated from configs/session/i3/workspaces/workspaces.yaml.",
        "# Run configs/session/i3/workspaces/workspaces.py generate-i3 --write after changing YAML.",
        "################################################################################",
        "",
    ]

    for workspace in workspaces:
        lines.append(f"# {workspace.name}")
        lines.append(f'set $ws{workspace.key} "{workspace.i3_name}"')

    return "\n".join(lines) + "\n"


def command_generate_i3(args: argparse.Namespace) -> int:
    config = load_config(args.config)
    output = generate_i3_config(load_workspaces(config))

    if args.write:
        args.output.write_text(output, encoding="utf-8")
        return 0

    sys.stdout.write(output)
    return 0


def generate_polybar_config(workspaces: list[Workspace]) -> str:
    lines = [
        "[module/i3]",
        "# Generated from configs/session/i3/workspaces/workspaces.yaml.",
        "# Run configs/session/i3/workspaces/workspaces.py generate-polybar --write after changing YAML.",
        "# https://github.com/polybar/polybar/wiki/Module:-i3",
        "type = internal/i3",
        "",
        "; Show all workspaces, including ones on unfocused monitors.",
        "pin-workspaces = false",
        "",
        "; Sort workspaces by their i3 workspace number rather than creation order.",
        "index-sort = true",
        "",
        "; Dynamic workspaces put their display icon directly in the i3 name.",
        "fuzzy-match = false",
        "",
    ]

    icon_index = 0
    for workspace in workspaces:
        lines.append(f"ws-icon-{icon_index} = {workspace.i3_name};{workspace.icon}")
        icon_index += 1

    lines.extend(
        [
            "ws-icon-default = ",
            "",
            "; Render workspace names after their numeric prefix. Dynamic names are only icons.",
            "strip-wsnumbers = true",
            "",
            "label-mode-padding = 2",
            "",
            "label-focused = %name%",
            "label-focused-foreground = ${colours.green}",
            "label-focused-background = ${colours.selection}",
            "label-focused-underline = ${colours.purple}",
            "label-focused-padding = 4",
            "",
            "label-unfocused = %name%",
            "label-unfocused-foreground = ${colours.foreground}",
            "label-unfocused-padding = 4",
            "",
            "label-visible = %name%",
            "label-visible-foreground = ${colours.orange}",
            "label-visible-underline = ${colours.primary}",
            "label-visible-padding = 4",
            "",
            "label-urgent = %name%",
            "label-urgent-foreground = ${colours.background}",
            "label-urgent-background = ${colours.pink}",
            "label-urgent-underline = ${colours.orange}",
            "label-urgent-padding = 4",
            "",
        ]
    )

    return "\n".join(lines)


def command_generate_polybar(args: argparse.Namespace) -> int:
    config = load_config(args.config)
    output = generate_polybar_config(load_workspaces(config))

    if args.write:
        args.output.write_text(output, encoding="utf-8")
        return 0

    sys.stdout.write(output)
    return 0


def i3_msg(*arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["i3-msg", *arguments],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def i3_result_succeeded(result: subprocess.CompletedProcess[str]) -> bool:
    if result.returncode != 0:
        return False

    try:
        parsed = json.loads(result.stdout)
    except json.JSONDecodeError:
        return False

    if not isinstance(parsed, list):
        return False

    return all(
        isinstance(item, dict) and item.get("success") is True for item in parsed
    )


def i3_result_error(result: subprocess.CompletedProcess[str]) -> str:
    try:
        parsed = json.loads(result.stdout)
    except json.JSONDecodeError:
        return result.stderr.strip()

    if not isinstance(parsed, list):
        return result.stderr.strip()

    for item in parsed:
        if isinstance(item, dict) and isinstance(item.get("error"), str):
            return item["error"]

    return result.stderr.strip()


def get_i3_tree() -> dict[str, Any]:
    result = i3_msg("-t", "get_tree")
    if result.returncode != 0:
        return {}

    try:
        parsed = json.loads(result.stdout)
    except json.JSONDecodeError:
        return {}

    return parsed if isinstance(parsed, dict) else {}


def focused_window_node(node: dict[str, Any]) -> dict[str, Any] | None:
    match = (
        node
        if node.get("focused") is True
        and node.get("window") is not None
        and isinstance(node.get("id"), int)
        else None
    )

    for child_key in ("nodes", "floating_nodes"):
        children = node.get(child_key, [])
        if not isinstance(children, list):
            continue
        for child in children:
            if not isinstance(child, dict):
                continue
            child_match = focused_window_node(child)
            if child_match is not None:
                return child_match

    return match


def window_from_node(node: dict[str, Any]) -> PromotedWindow:
    properties = node.get("window_properties", {})
    window_class = ""
    instance = ""
    if isinstance(properties, dict):
        window_class = str(properties.get("class", ""))
        instance = str(properties.get("instance", ""))

    title = str(node.get("name", "")) or window_class or instance or "Window"
    return PromotedWindow(
        con_id=int(node["id"]),
        window_class=window_class,
        instance=instance,
        title=title,
    )


def iter_windows(
    node: dict[str, Any],
    workspace_name: str = "",
) -> list[tuple[int, str, str, str]]:
    windows: list[tuple[int, str, str, str]] = []
    node_type = node.get("type")
    current_workspace = (
        str(node.get("name", "")) if node_type == "workspace" else workspace_name
    )

    if (
        node.get("window") is not None
        and isinstance(node.get("id"), int)
        and is_switchable_window(node)
    ):
        properties = node.get("window_properties", {})
        window_class = ""
        if isinstance(properties, dict):
            window_class = str(properties.get("class", ""))
        title = str(node.get("name", "")) or window_class or "Window"
        windows.append((int(node["id"]), current_workspace, window_class, title))

    for child_key in ("nodes", "floating_nodes"):
        children = node.get(child_key, [])
        if not isinstance(children, list):
            continue
        for child in children:
            if isinstance(child, dict):
                windows.extend(iter_windows(child, current_workspace))

    return windows


def is_switchable_window(node: dict[str, Any]) -> bool:
    properties = node.get("window_properties", {})
    window_class = ""
    window_instance = ""
    if isinstance(properties, dict):
        window_class = str(properties.get("class", "")).lower()
        window_instance = str(properties.get("instance", "")).lower()

    window_type = str(node.get("window_type", "")).lower()
    title = str(node.get("name", "")).lower()
    marks = node.get("marks", [])
    is_scratchpad_window = isinstance(marks, list) and any(
        str(mark).startswith("scratch-") for mark in marks
    )

    return (
        window_type != "dock"
        and window_class != "polybar"
        and window_instance != "polybar"
        and title != "polybar-i3bar"
        and not is_scratchpad_window
    )


def vscode_workspace_label(title: str) -> str:
    suffix = " - Visual Studio Code"
    if not title.endswith(suffix):
        return ""
    remainder = title[: -len(suffix)]
    workspace = remainder.rsplit(" - ", 1)[-1].strip()
    return workspace


def pango_escape(value: str) -> str:
    return (
        value.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def command_window_switcher(args: argparse.Namespace) -> int:
    windows = iter_windows(get_i3_tree())

    if not windows:
        return 0

    entries = []
    for con_id, _workspace_name, window_class, title in windows:
        label = window_class
        if window_class.lower() in {"code", "com.microsoft.vscode"}:
            label = vscode_workspace_label(title) or "Code"
        entries.append(
            (
                con_id,
                (
                    f"<span color='#FF5555'>{pango_escape(label[:18])}</span> "
                    f"{pango_escape(title)}"
                    f"\0icon\x1f{window_class.lower()}"
                ),
            )
        )

    rofi = subprocess.run(
        [
            "rofi",
            "-x11",
            "-dmenu",
            "-i",
            "-show-icons",
            "-markup-rows",
            "-config",
            str(args.rofi_config),
            "-p",
            "Windows",
            "-format",
            "i",
            "-kb-cancel",
            "Alt+Escape,Escape",
            "-kb-row-down",
            "Alt+Tab,Down",
            "-kb-row-up",
            "Alt+ISO_Left_Tab,Up",
            "-theme-str",
            (
                "listview { lines: 12; dynamic: false; scrollbar: true; } "
                "element { padding: 6px; } "
                "element-text { vertical-align: 0.5; }"
            ),
        ],
        input="\n".join(entry for _con_id, entry in entries),
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )

    if rofi.returncode != 0:
        return rofi.returncode

    selected_index = rofi.stdout.strip()
    if not selected_index.isdigit():
        return 1

    index = int(selected_index)
    if index < 0 or index >= len(entries):
        return 1

    con_id = entries[index][0]
    result = i3_msg(f"[con_id={con_id}]", "focus")
    return result.returncode


def next_dynamic_workspace_number() -> int:
    result = i3_msg("-t", "get_workspaces")
    if result.returncode != 0:
        return 10

    try:
        existing = json.loads(result.stdout)
    except json.JSONDecodeError:
        return 10

    if not isinstance(existing, list):
        return 10

    used_numbers = {
        int(workspace["num"])
        for workspace in existing
        if isinstance(workspace, dict)
        and isinstance(workspace.get("num"), int)
        and int(workspace["num"]) > 0
    }
    candidate = 10
    while candidate in used_numbers or candidate in RESERVED_DYNAMIC_WORKSPACE_NUMBERS:
        candidate += 1
    return candidate


def remove_json_comments(content: str) -> str:
    output: list[str] = []
    index = 0
    in_string = False
    escaped = False
    in_line_comment = False
    in_block_comment = False

    while index < len(content):
        char = content[index]
        next_char = content[index + 1] if index + 1 < len(content) else ""

        if in_line_comment:
            if char == "\n":
                in_line_comment = False
                output.append(char)
            index += 1
            continue

        if in_block_comment:
            if char == "*" and next_char == "/":
                in_block_comment = False
                index += 2
                continue
            if char == "\n":
                output.append(char)
            index += 1
            continue

        if in_string:
            output.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue

        if char == '"':
            in_string = True
            output.append(char)
            index += 1
            continue

        if char == "/" and next_char == "/":
            in_line_comment = True
            index += 2
            continue

        if char == "/" and next_char == "*":
            in_block_comment = True
            index += 2
            continue

        output.append(char)
        index += 1

    return "".join(output)


def load_code_workspace(workspace_path: Path) -> dict[str, Any]:
    try:
        parsed = json.loads(
            remove_json_comments(workspace_path.read_text(encoding="utf-8"))
        )
    except (OSError, json.JSONDecodeError):
        return {}

    return parsed if isinstance(parsed, dict) else {}


def ancestor_workspace_config_paths(directory: Path) -> list[Path]:
    try:
        current = directory.resolve(strict=False)
    except OSError:
        current = directory

    candidates = [current / ".github" / "config.toml"]
    candidates.extend(parent / ".github" / "config.toml" for parent in current.parents)
    return candidates


def workspace_folder_path(raw_folder: dict[str, Any], base_path: Path) -> Path | None:
    raw_path = raw_folder.get("path")
    if isinstance(raw_path, str) and raw_path:
        folder_path = Path(raw_path).expanduser()
        if not folder_path.is_absolute():
            folder_path = base_path / folder_path
        return folder_path

    raw_uri = raw_folder.get("uri")
    if not isinstance(raw_uri, str) or not raw_uri:
        return None

    parsed = urlparse(raw_uri)
    if parsed.scheme != "file":
        return None

    return Path(unquote(parsed.path)).expanduser()


def workspace_config_paths_for_target(target: Path) -> list[Path]:
    candidates: list[Path] = []
    resolved_target = target.expanduser()

    if resolved_target.is_dir():
        candidates.extend(ancestor_workspace_config_paths(resolved_target))
    else:
        candidates.extend(ancestor_workspace_config_paths(resolved_target.parent))

    if resolved_target.is_file() and resolved_target.suffix == ".code-workspace":
        workspace = load_code_workspace(resolved_target)
        folders = workspace.get("folders", []) if isinstance(workspace, dict) else []
        if isinstance(folders, list):
            for folder in folders:
                if not isinstance(folder, dict):
                    continue
                folder_path = workspace_folder_path(folder, resolved_target.parent)
                if folder_path is None:
                    continue
                candidates.extend(ancestor_workspace_config_paths(folder_path))

    unique_candidates: list[Path] = []
    seen: set[Path] = set()
    for candidate in candidates:
        if candidate in seen:
            continue
        seen.add(candidate)
        unique_candidates.append(candidate)

    return unique_candidates


def project_workspace_icon(target: Path) -> str:
    for config_path in workspace_config_paths_for_target(target):
        if not config_path.is_file():
            continue
        try:
            config = tomllib.loads(config_path.read_text(encoding="utf-8"))
        except (OSError, tomllib.TOMLDecodeError) as error:
            print(
                f"Ignoring invalid workspace icon config: {config_path}: {error}",
                file=sys.stderr,
            )
            continue

        workspace = config.get("workspace")
        if not isinstance(workspace, dict):
            continue

        icon = workspace.get("icon")
        if isinstance(icon, str) and icon.strip():
            return icon.strip()

    return ""


def window_icon_rule_matches(rule: WindowIconRule, window: PromotedWindow) -> bool:
    class_matches = (
        not rule.window_class
        or rule.window_class.casefold() == window.window_class.casefold()
    )
    instance_matches = (
        not rule.instance or rule.instance.casefold() == window.instance.casefold()
    )
    return class_matches and instance_matches


def window_icon_identity(
    icon_config: WindowIconConfig, window: PromotedWindow
) -> tuple[str, str]:
    for rule in icon_config.rules:
        if window_icon_rule_matches(rule, window):
            return rule.slug or DEFAULT_WINDOW_SLUG, rule.icon

    return DEFAULT_WINDOW_SLUG, icon_config.fallback_icon


def command_promote_focused(args: argparse.Namespace) -> int:
    config = load_config(args.config)
    icon_config = load_window_icon_config(config)
    node = focused_window_node(get_i3_tree())

    if node is None:
        print("No focused i3-managed window found", file=sys.stderr)
        return 1

    if not is_switchable_window(node):
        print("Focused window is not eligible for promotion", file=sys.stderr)
        return 1

    window = window_from_node(node)
    slug, icon = window_icon_identity(icon_config, window)
    number = next_dynamic_workspace_number()
    workspace_name = f"{number}:{icon}"

    move_result = i3_msg(
        f"[con_id={window.con_id}]",
        "move",
        "container",
        "to",
        "workspace",
        "number",
        workspace_name,
    )
    if not i3_result_succeeded(move_result):
        print(
            i3_result_error(move_result) or "Could not move focused window",
            file=sys.stderr,
        )
        return 1

    switch_result = i3_msg("workspace", "number", workspace_name)
    if not i3_result_succeeded(switch_result):
        print(
            i3_result_error(switch_result) or "Could not switch to promoted workspace",
            file=sys.stderr,
        )
        return 1

    if args.verbose:
        print(
            f"Promoted {window.title} ({window.window_class or window.instance or slug}) to {workspace_name}"
        )

    return 0


def command_launch(args: argparse.Namespace) -> int:
    config = load_config(args.config)
    applications = load_dynamic_applications(config)
    application = applications.get(args.application)
    if application is None:
        print(f"Unknown dynamic application: {args.application}", file=sys.stderr)
        return 1

    target = Path(args.target).expanduser() if args.target else None
    indicator = (project_workspace_icon(target) if target else "") or application.icon
    number = next_dynamic_workspace_number()
    workspace_name = f"{number}:{indicator}"

    switch_result = i3_msg("workspace", "number", workspace_name)
    if switch_result.returncode != 0:
        print(switch_result.stderr.strip() or "Could not create workspace", file=sys.stderr)
        return switch_result.returncode

    command = [*application.command, *([str(target)] if target else [])]
    try:
        subprocess.Popen(command, start_new_session=True)
    except FileNotFoundError:
        print(f"Command not found: {command[0]}", file=sys.stderr)
        return 1
    return 0


def i3_quote(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def resolve_executable(executable: str) -> str:
    found = shutil.which(executable)
    return str(Path(found).resolve()) if found else executable


def dynamic_icon_for_command(
    applications: dict[str, DynamicApplication], argv: list[str]
) -> str:
    """Return the icon of the dynamic application that runs the same executable."""
    wanted = resolve_executable(argv[0])
    for application in applications.values():
        if application.command and resolve_executable(application.command[0]) == wanted:
            return application.icon
    return ""


def find_workspace_node(node: dict[str, Any], number: int) -> dict[str, Any] | None:
    if node.get("type") == "workspace" and node.get("num") == number:
        return node

    for child_key in ("nodes", "floating_nodes"):
        children = node.get(child_key, [])
        if not isinstance(children, list):
            continue
        for child in children:
            if isinstance(child, dict):
                match = find_workspace_node(child, number)
                if match is not None:
                    return match

    return None


def first_window_node(node: dict[str, Any]) -> dict[str, Any] | None:
    if node.get("window") is not None and isinstance(node.get("id"), int):
        return node

    for child_key in ("nodes", "floating_nodes"):
        children = node.get(child_key, [])
        if not isinstance(children, list):
            continue
        for child in children:
            if isinstance(child, dict):
                match = first_window_node(child)
                if match is not None:
                    return match

    return None


def command_launch_command(args: argparse.Namespace) -> int:
    argv = list(args.argv)
    if argv and argv[0] == "--":
        argv = argv[1:]
    if not argv:
        print("launch-command needs a command to run", file=sys.stderr)
        return 2

    config = load_config(args.config)
    icon_config = load_window_icon_config(config)
    known_icon = dynamic_icon_for_command(load_dynamic_applications(config), argv)
    number = next_dynamic_workspace_number()
    workspace_name = f"{number}:{known_icon or icon_config.fallback_icon}"

    switch_result = i3_msg("workspace", "number", workspace_name)
    if not i3_result_succeeded(switch_result):
        print(
            i3_result_error(switch_result) or "Could not create workspace",
            file=sys.stderr,
        )
        return 1

    # Without a dynamic.* match the window class decides the icon, and that
    # is only known once the window exists. Start the watcher before the
    # program so that it cannot miss a fast window.
    if not known_icon:
        subprocess.Popen(
            [
                sys.executable,
                str(Path(__file__).resolve()),
                "--config",
                str(args.config),
                "set-workspace-icon",
                "--workspace-number",
                str(number),
            ],
            start_new_session=True,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
        )

    try:
        subprocess.Popen(
            argv,
            start_new_session=True,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        print(f"Command not found: {argv[0]}", file=sys.stderr)
        return 1

    if args.verbose:
        print(f"Started {' '.join(argv)} on workspace {workspace_name}")

    return 0


def command_set_workspace_icon(args: argparse.Namespace) -> int:
    icon_config = load_window_icon_config(load_config(args.config))
    deadline = time.monotonic() + args.timeout

    while time.monotonic() < deadline:
        workspace = find_workspace_node(get_i3_tree(), args.workspace_number)
        window_node = first_window_node(workspace) if workspace is not None else None
        if workspace is not None and window_node is not None:
            _slug, icon = window_icon_identity(icon_config, window_from_node(window_node))
            current_name = str(workspace.get("name", ""))
            new_name = f"{args.workspace_number}:{icon}"
            if current_name == new_name:
                return 0

            rename_result = i3_msg(
                "rename", "workspace", i3_quote(current_name), "to", i3_quote(new_name)
            )
            if not i3_result_succeeded(rename_result):
                print(
                    i3_result_error(rename_result) or "Could not rename workspace",
                    file=sys.stderr,
                )
                return 1
            return 0

        time.sleep(WINDOW_ICON_POLL_SECONDS)

    # No window appeared in time: the workspace keeps the fallback icon.
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Manage i3 session workspaces from configs/session/i3/workspaces/workspaces.yaml."
    )
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    subparsers = parser.add_subparsers(dest="command", required=True)

    generate_i3 = subparsers.add_parser("generate-i3")
    generate_i3.add_argument("--write", action="store_true")
    generate_i3.add_argument("--output", type=Path, default=DEFAULT_I3_INCLUDE)
    generate_i3.set_defaults(func=command_generate_i3)

    generate_polybar = subparsers.add_parser("generate-polybar")
    generate_polybar.add_argument("--write", action="store_true")
    generate_polybar.add_argument("--output", type=Path, default=DEFAULT_POLYBAR_INCLUDE)
    generate_polybar.set_defaults(func=command_generate_polybar)

    window_switcher = subparsers.add_parser("window-switcher")
    window_switcher.add_argument("--rofi-config", type=Path, default=DEFAULT_ROFI_CONFIG)
    window_switcher.set_defaults(func=command_window_switcher)

    launch = subparsers.add_parser("launch")
    launch.add_argument("--application", required=True)
    launch.add_argument("--target", default=None)
    launch.add_argument("--label", default="")
    launch.set_defaults(func=command_launch)

    launch_command = subparsers.add_parser(
        "launch-command",
        help="Start any command on a new dynamic workspace (used by the Rofi launcher).",
    )
    launch_command.add_argument("--verbose", action="store_true")
    launch_command.add_argument("argv", nargs=argparse.REMAINDER)
    launch_command.set_defaults(func=command_launch_command)

    set_workspace_icon = subparsers.add_parser(
        "set-workspace-icon",
        help="Wait for the first window on a workspace and set its icon from window_icons.",
    )
    set_workspace_icon.add_argument("--workspace-number", type=int, required=True)
    set_workspace_icon.add_argument("--timeout", type=float, default=WINDOW_ICON_WAIT_SECONDS)
    set_workspace_icon.set_defaults(func=command_set_workspace_icon)

    promote_focused = subparsers.add_parser("promote-focused")
    promote_focused.add_argument("--verbose", action="store_true")
    promote_focused.set_defaults(func=command_promote_focused)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
