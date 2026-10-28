#!/usr/bin/env -S node --experimental-strip-types

// Reject direct terminal styling in shell code outside the terminal UI facade.
//
// Scans tracked and untracked (not ignored) shell and awk files below bashrc/, bin/,
// configs/, scripts/, and tools/ for raw ANSI escapes, direct Gum styling
// or widget calls, and tput colour calls. Use the dnb_ui_* functions from
// bashrc/lib/00-core/dnb-core-ui.bash instead (see docs/terminal-ui.md).
//
// Usage:
//   node --experimental-strip-types scripts/lint-terminal-ui.ts

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

const SCAN_ROOTS = ["bashrc", "bin", "configs", "scripts", "tools"];

// Files that implement the facade or test it.
const ALLOWED_FILES = new Set([
  "bashrc/lib/00-core/dnb-core-colors.bash",
  "bashrc/lib/00-core/dnb-core-log.bash",
  "bashrc/lib/00-core/dnb-core-ui-theme.bash",
  "bashrc/lib/00-core/dnb-core-ui.bash",
  "bashrc/helpers/tests/dnb-ui-test.sh",
]);

// Lines that configure other programs' own colours, not DNB output.
const ALLOWED_LINES: RegExp[] = [/\bLESS_TERMCAP_\w+=/u];

const RULES: Array<{ name: string; pattern: RegExp }> = [
  { name: "raw ANSI escape", pattern: /\\(?:e|E|033|x1b|x1B|u001b)\[/u },
  {
    name: "direct gum styling or widget",
    pattern:
      /\bgum\s+(?:style|choose|filter|input|confirm|spin|table|write|pager|format|join)\b/u,
  },
  {
    name: "tput colour or attribute",
    pattern: /\btput\s+(?:setaf|setab|bold|sgr0|smul|rev|dim)\b/u,
  },
];

const SHELL_EXTENSIONS = /\.(?:sh|bash|awk)$/u;
const SKIP_EXTENSIONS =
  /\.(?:md|json|jsonc|ts|js|mjs|cjs|yaml|yml|py|css|scss|svg|png|jpg|ttf|otf|woff2?|tmTheme|txt|conf|ini|toml|xml|lock|desktop|rasi)$/u;

function listFiles(): string[] {
  const output = execFileSync(
    "git",
    [
      "ls-files",
      "-z",
      "--cached",
      "--others",
      "--exclude-standard",
      "--",
      ...SCAN_ROOTS,
    ],
    { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 },
  );
  return output.split("\0").filter((file) => file !== "");
}

function isShellFile(file: string, content: string): boolean {
  if (SHELL_EXTENSIONS.test(file)) {
    return true;
  }
  if (SKIP_EXTENSIONS.test(file)) {
    return false;
  }
  const firstLine = content.slice(0, 200).split("\n", 1)[0] ?? "";
  return /^#!.*\b(?:bash|sh)\b/u.test(firstLine);
}

function main(): void {
  if (process.argv.slice(2).includes("--help")) {
    process.stdout.write("Usage: lint-terminal-ui.ts\n");
    return;
  }

  const findings: string[] = [];
  for (const file of listFiles()) {
    if (ALLOWED_FILES.has(file) || file.includes("/node_modules/")) {
      continue;
    }
    let content = "";
    try {
      content = readFileSync(file, "utf8");
    } catch {
      continue;
    }
    if (!isShellFile(file, content)) {
      continue;
    }
    content.split("\n").forEach((line, index) => {
      if (ALLOWED_LINES.some((pattern) => pattern.test(line))) {
        return;
      }
      for (const rule of RULES) {
        if (rule.pattern.test(line)) {
          findings.push(`${file}:${index + 1}: ${rule.name}: ${line.trim()}`);
        }
      }
    });
  }

  if (findings.length > 0) {
    process.stderr.write(`${findings.join("\n")}\n`);
    process.stderr.write(
      `\n${findings.length} direct terminal styling finding(s). Use the dnb_ui_* functions (docs/terminal-ui.md).\n`,
    );
    process.exitCode = 1;
  }
}

main();
