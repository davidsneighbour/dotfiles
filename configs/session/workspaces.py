#!/usr/bin/python3

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml


REPO_SESSION_DIR = Path(__file__).resolve().parent
DEFAULT_CONFIG = REPO_SESSION_DIR / "workspaces.yaml"
DEFAULT_I3_INCLUDE = REPO_SESSION_DIR / "i3" / "configs" / "workspaces.conf"
DEFAULT_POLYBAR_INCLUDE = (
    REPO_SESSION_DIR / "polybar" / "configs" / "07-module-i3.ini"
)
DEFAULT_ROFI_CONFIG = REPO_SESSION_DIR / "rofi" / "config.alt-tab-switcher.rasi"


@dataclass(frozen=True)
class Workspace:
    key: int
    name: str
    label: str
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
                label=str(raw_workspace["label"]),
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


def generate_i3_config(workspaces: list[Workspace]) -> str:
    lines = [
        "################################################################################",
        "# Generated from configs/session/workspaces.yaml.",
        "# Run configs/session/workspaces.py generate-i3 --write after changing YAML.",
        "################################################################################",
        "",
    ]

    for workspace in workspaces:
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


def generate_polybar_config(
    workspaces: list[Workspace],
    dynamic_applications: dict[str, DynamicApplication],
) -> str:
    lines = [
        "[module/i3]",
        "# Generated from configs/session/workspaces.yaml.",
        "# Run configs/session/workspaces.py generate-polybar --write after changing YAML.",
        "# https://github.com/polybar/polybar/wiki/Module:-i3",
        "type = internal/i3",
        "",
        "; Show all workspaces, including ones on unfocused monitors.",
        "pin-workspaces = false",
        "",
        "; Sort workspaces by their i3 workspace number rather than creation order.",
        "index-sort = true",
        "",
        "; Let dynamic names such as 10:code:dotfiles match the code icon rule.",
        "fuzzy-match = true",
        "",
    ]

    icon_index = 0
    for workspace in workspaces:
        lines.append(f"ws-icon-{icon_index} = {workspace.i3_name};{workspace.icon}")
        icon_index += 1

    for application in dynamic_applications.values():
        lines.append(
            f"ws-icon-{icon_index} = {application.workspace_prefix};{application.icon}"
        )
        icon_index += 1

    lines.extend(
        [
            "ws-icon-default = ",
            "",
            "; Render only icons. Dynamic workspace names remain internal.",
            "strip-wsnumbers = false",
            "",
            "label-mode-padding = 2",
            "",
            "label-focused = %icon%",
            "label-focused-foreground = ${colours.green}",
            "label-focused-background = ${colours.selection}",
            "label-focused-underline = ${colours.purple}",
            "label-focused-padding = 4",
            "",
            "label-unfocused = %icon%",
            "label-unfocused-foreground = ${colours.foreground}",
            "label-unfocused-padding = 4",
            "",
            "label-visible = %icon%",
            "label-visible-foreground = ${colours.orange}",
            "label-visible-underline = ${colours.primary}",
            "label-visible-padding = 4",
            "",
            "label-urgent = %icon%",
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
    output = generate_polybar_config(
        load_workspaces(config),
        load_dynamic_applications(config),
    )

    if args.write:
        args.output.write_text(output, encoding="utf-8")
        return 0

    sys.stdout.write(output)
    return 0


def slugify(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9_.-]+", "-", value.strip()).strip("-")
    return slug.lower() or "workspace"


def i3_msg(*arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["i3-msg", *arguments],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def get_i3_tree() -> dict[str, Any]:
    result = i3_msg("-t", "get_tree")
    if result.returncode != 0:
        return {}

    try:
        parsed = json.loads(result.stdout)
    except json.JSONDecodeError:
        return {}

    return parsed if isinstance(parsed, dict) else {}


def workspace_icon_for_name(
    workspace_name: str,
    workspaces: list[Workspace],
    dynamic_applications: dict[str, DynamicApplication],
) -> str:
    for workspace in workspaces:
        if workspace_name == workspace.i3_name:
            return workspace.icon

    segments = workspace_name.split(":", 2)
    if len(segments) >= 2:
        dynamic_name = segments[1]
        for application in dynamic_applications.values():
            if application.workspace_prefix == dynamic_name:
                return application.icon

    return ""


def iter_windows(
    node: dict[str, Any],
    workspace_name: str = "",
) -> list[tuple[int, str, str, str]]:
    windows: list[tuple[int, str, str, str]] = []
    node_type = node.get("type")
    current_workspace = (
        str(node.get("name", "")) if node_type == "workspace" else workspace_name
    )

    if node.get("window") is not None and isinstance(node.get("id"), int):
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


def pango_escape(value: str) -> str:
    return (
        value.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def command_window_switcher(args: argparse.Namespace) -> int:
    config = load_config(args.config)
    workspaces = load_workspaces(config)
    dynamic_applications = load_dynamic_applications(config)
    windows = iter_windows(get_i3_tree())

    if not windows:
        return 0

    entries = [
        (
            con_id,
            (
                "<span font='lucide'>"
                f"{pango_escape(workspace_icon_for_name(workspace_name, workspaces, dynamic_applications))}"
                "</span> "
                f"<span color='#708CA9'>{pango_escape(window_class[:18])}</span> "
                f"{pango_escape(title)}"
            ),
        )
        for con_id, workspace_name, window_class, title in windows
    ]

    rofi = subprocess.run(
        [
            "rofi",
            "-x11",
            "-dmenu",
            "-i",
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
    while candidate in used_numbers:
        candidate += 1
    return candidate


def command_launch(args: argparse.Namespace) -> int:
    config = load_config(args.config)
    applications = load_dynamic_applications(config)
    application = applications.get(args.application)
    if application is None:
        print(f"Unknown dynamic application: {args.application}", file=sys.stderr)
        return 1

    target = Path(args.target).expanduser()
    label = args.label or (target.stem if target.is_file() else target.name)
    number = next_dynamic_workspace_number()
    workspace_name = f"{number}:{application.workspace_prefix}:{slugify(label)}"

    switch_result = i3_msg("workspace", "number", workspace_name)
    if switch_result.returncode != 0:
        print(switch_result.stderr.strip() or "Could not create workspace", file=sys.stderr)
        return switch_result.returncode

    command = [*application.command, str(target)]
    try:
        subprocess.Popen(command, start_new_session=True)
    except FileNotFoundError:
        print(f"Command not found: {command[0]}", file=sys.stderr)
        return 1
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Manage i3 session workspaces from configs/session/workspaces.yaml."
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
    launch.add_argument("--target", required=True)
    launch.add_argument("--label", default="")
    launch.set_defaults(func=command_launch)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
