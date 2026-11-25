#!/usr/bin/python3
"""Turn window-inspector.sh output and a Lucide icon name into a window_icons rule.

Read-only helper for the workspace-window-icon agent skill. It never writes
workspaces.yaml: it prints the proposed rule on stdout and a short report on
stderr, so the agent can place the rule by hand and run the helper again to
verify the result.
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[3]
WORKSPACES_DIR = REPO_ROOT / "configs" / "session" / "i3" / "workspaces"
DEFAULT_CONFIG = WORKSPACES_DIR / "workspaces.yaml"
DEFAULT_FONT_INFO = REPO_ROOT / "configs" / "fonts" / "System" / "lucide" / "info.json"

# Reuse the real loader and matcher, so this helper cannot drift from them.
sys.dont_write_bytecode = True
sys.path.insert(0, str(WORKSPACES_DIR))
import workspaces as ws  # noqa: E402

HELP_EPILOG = """\
Examples:
  # Propose a rule for every Signal window (class match).
  window-icon-rule.py --icon messages-square --input inspector.txt

  # Same, from the clipboard, with an explicit name.
  xclip -o -selection clipboard | window-icon-rule.py --icon messages-square --slug signal

  # Chrome --app window: match class and instance.
  window-icon-rule.py --icon cookie --match both --slug cookieclicker --input inspector.txt

  # Find Lucide icon names.
  window-icon-rule.py --search message

Exit codes:
  0  Rule proposed, or the window already resolves to the requested icon.
  1  Bad input: no WM_CLASS in the inspector output, or unknown icon name.
  2  Usage error.
"""


@dataclass(frozen=True)
class InspectedWindow:
    window_class: str
    instance: str
    title: str


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="window-icon-rule.py",
        description=(
            "Read the output of window-inspector.sh (Ctrl+Shift+Alt+I), resolve a "
            "Lucide icon name to its codepoint, and print a window_icons rule for "
            "workspaces.yaml. Nothing is written."
        ),
        epilog=HELP_EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--icon", help="Lucide icon name, for example messages-square.")
    parser.add_argument(
        "--slug",
        help="Short workspace name for the rule (default: the window class in kebab-case).",
    )
    parser.add_argument(
        "--match",
        choices=("class", "instance", "both"),
        default="class",
        help="Which WM_CLASS fields the rule matches (default: class, which covers every window of the program).",
    )
    parser.add_argument(
        "--label",
        help="Program name for the YAML comment (default: the window title).",
    )
    parser.add_argument(
        "--input",
        type=Path,
        help="File with the inspector output (default: read stdin).",
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=DEFAULT_CONFIG,
        help=f"workspaces.yaml to check against (default: {DEFAULT_CONFIG.relative_to(REPO_ROOT)}).",
    )
    parser.add_argument(
        "--font-info",
        type=Path,
        default=DEFAULT_FONT_INFO,
        help=f"Lucide info.json (default: {DEFAULT_FONT_INFO.relative_to(REPO_ROOT)}).",
    )
    parser.add_argument(
        "--search",
        metavar="TERM",
        help="List Lucide icon names that contain TERM, then exit.",
    )
    parser.add_argument("--verbose", action="store_true", help="Print the parsed fields and every matching rule.")

    args = parser.parse_args(argv)
    if not args.search and not args.icon:
        parser.print_help(sys.stderr)
        parser.exit(2, "\nError: --icon or --search is required.\n")
    if args.input is None and not args.search and sys.stdin.isatty():
        parser.print_help(sys.stderr)
        parser.exit(2, "\nError: give --input FILE or pipe the inspector output on stdin.\n")
    return args


def info(message: str) -> None:
    print(message, file=sys.stderr)


def load_lucide(font_info: Path) -> dict[str, int]:
    if not font_info.is_file():
        raise SystemExit(f"Error: Lucide info.json not found: {font_info}")
    raw = json.loads(font_info.read_text(encoding="utf-8"))
    icons: dict[str, int] = {}
    for name, entry in raw.items():
        encoded = str(entry.get("encodedCode", "")).lstrip("\\")
        if encoded:
            icons[name] = int(encoded, 16)
    return icons


def search_icons(icons: dict[str, int], term: str) -> list[str]:
    needle = term.strip().lower()
    return sorted(name for name in icons if needle in name)


def resolve_icon(icons: dict[str, int], name: str) -> int:
    key = name.strip().lower()
    if key in icons:
        return icons[key]
    close = difflib.get_close_matches(key, icons.keys(), n=8, cutoff=0.6)
    contains = search_icons(icons, key)[:8]
    suggestions = list(dict.fromkeys(close + contains))
    hint = f" Did you mean: {', '.join(suggestions)}?" if suggestions else ""
    raise SystemExit(f"Error: no Lucide icon named '{name}'.{hint} Use --search TERM to list names.")


def escape(codepoint: int) -> str:
    if codepoint > 0xFFFF:
        raise SystemExit(
            f"Error: U+{codepoint:X} needs more than 4 hex digits; workspaces.yaml only uses \\uXXXX escapes."
        )
    return f"\\u{codepoint:04X}"


WM_CLASS_RE = re.compile(r'^WM_CLASS\([^)]*\)\s*=\s*"([^"]*)",\s*"([^"]*)"', re.MULTILINE)
I3_MATCH_RE = re.compile(r'^\[class="([^"]*)"\s+instance="([^"]*)"\]', re.MULTILINE)
WM_NAME_RE = re.compile(r'^WM_NAME\([^)]*\)\s*=\s*"(.*)"\s*$', re.MULTILINE)
XDOTOOL_NAME_RE = re.compile(r"^Name:\s*(.*?)\s*$", re.MULTILINE)


def parse_inspector(text: str) -> InspectedWindow:
    instance = window_class = ""
    if match := WM_CLASS_RE.search(text):
        instance, window_class = match.group(1), match.group(2)
    elif match := I3_MATCH_RE.search(text):
        window_class, instance = match.group(1), match.group(2)
    if not window_class and not instance:
        raise SystemExit(
            "Error: no WM_CLASS found. Paste the full window-inspector.sh output "
            "(the xprop section or the 'suggested i3 match' line)."
        )

    title = ""
    if match := WM_NAME_RE.search(text):
        title = match.group(1)
    elif match := XDOTOOL_NAME_RE.search(text):
        title = match.group(1)
    return InspectedWindow(window_class=window_class, instance=instance, title=title)


def default_slug(window: InspectedWindow) -> str:
    source = window.window_class or window.instance
    slug = re.sub(r"[^a-z0-9]+", "-", source.lower()).strip("-")
    return slug or ws.DEFAULT_WINDOW_SLUG


def describe(rule: ws.WindowIconRule) -> str:
    fields = []
    if rule.window_class:
        fields.append(f"class={rule.window_class}")
    if rule.instance:
        fields.append(f"instance={rule.instance}")
    fields.append(f"slug={rule.slug or '-'}")
    fields.append(f"icon={codepoint_text(rule.icon)}")
    return ", ".join(fields)


def codepoint_text(icon: str) -> str:
    return " ".join(f"U+{ord(char):04X}" for char in icon) or "(empty)"


def build_rule_yaml(
    window: InspectedWindow, match: str, slug: str, label: str, icon_name: str, icon_escape: str
) -> str:
    lines = [f"    # {label} (Lucide {icon_name})." if label else f"    # Lucide {icon_name}."]
    first = True
    for key, value in (
        ("class", window.window_class if match in ("class", "both") else ""),
        ("instance", window.instance if match in ("instance", "both") else ""),
    ):
        if not value:
            continue
        lines.append(f"    {'- ' if first else '  '}{key}: {value}")
        first = False
    lines.append(f"      slug: {slug}")
    lines.append(f'      icon: "{icon_escape}"')
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    icons = load_lucide(args.font_info)

    if args.search:
        names = search_icons(icons, args.search)
        for name in names:
            print(f"{name}\t{escape(icons[name])}")
        info(f"{len(names)} Lucide icon(s) contain '{args.search}'.")
        return 0

    codepoint = resolve_icon(icons, args.icon)
    icon_escape = escape(codepoint)
    glyph = chr(codepoint)

    text = args.input.read_text(encoding="utf-8") if args.input else sys.stdin.read()
    window = parse_inspector(text)

    if args.match in ("class", "both") and not window.window_class:
        raise SystemExit("Error: the inspector output has no class; use --match instance.")
    if args.match in ("instance", "both") and not window.instance:
        raise SystemExit("Error: the inspector output has no instance; use --match class.")

    slug = args.slug or default_slug(window)
    label = args.label if args.label is not None else window.title
    new_rule = ws.WindowIconRule(
        window_class=window.window_class if args.match in ("class", "both") else "",
        instance=window.instance if args.match in ("instance", "both") else "",
        slug=slug,
        icon=glyph,
    )

    icon_config = ws.load_window_icon_config(ws.load_config(args.config))
    probe = ws.PromotedWindow(
        con_id=0, window_class=window.window_class, instance=window.instance, title=window.title
    )
    current_slug, current_icon = ws.window_icon_identity(icon_config, probe)

    if args.verbose:
        info(f"Window: class={window.window_class!r} instance={window.instance!r} title={window.title!r}")
        info(f"Config: {args.config}")
        for index, rule in enumerate(icon_config.rules):
            if ws.window_icon_rule_matches(rule, probe):
                info(f"  matches rule #{index}: {describe(rule)}")

    info(f"Icon:    Lucide {args.icon.strip().lower()} -> U+{codepoint:04X} -> \"{icon_escape}\"")
    info(f"Now:     slug={current_slug}, icon={codepoint_text(current_icon)}")

    same_fields = [
        index
        for index, rule in enumerate(icon_config.rules)
        if rule.window_class.casefold() == new_rule.window_class.casefold()
        and rule.instance.casefold() == new_rule.instance.casefold()
    ]
    first_match = next(
        (index for index, rule in enumerate(icon_config.rules) if ws.window_icon_rule_matches(rule, probe)),
        None,
    )

    if current_icon == glyph and current_slug == slug:
        info("Status:  already configured. Nothing to change.")
        return 0

    if same_fields:
        index = same_fields[0]
        info(f"Status:  rule #{index} already uses these match fields ({describe(icon_config.rules[index])}).")
        info("Action:  change that rule's slug/icon in place. Do not add a second rule.")
    elif first_match is not None:
        blocker = icon_config.rules[first_match]
        more_specific = bool(blocker.window_class and blocker.instance) and not (
            new_rule.window_class and new_rule.instance
        )
        info(f"Status:  rule #{first_match} matches this window first ({describe(blocker)}).")
        if more_specific:
            info("Action:  that rule is more specific. Put the new rule after it; this window keeps its icon.")
        else:
            info(f"Action:  insert the new rule before rule #{first_match}; the first matching rule wins.")
    else:
        info("Status:  no rule matches this window yet (it gets the fallback icon).")
        info("Action:  add the rule to window_icons.rules, before any generic rule it should override.")

    print(build_rule_yaml(window, args.match, slug, label, args.icon.strip().lower(), icon_escape))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
