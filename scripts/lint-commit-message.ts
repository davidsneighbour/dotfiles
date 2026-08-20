#!/usr/bin/env node

import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const SCRIPT_NAME = path.basename(process.argv[1] ?? "lint-commit-message.ts");
const CUT_LINE = "# ------------------------ >8 ------------------------";

function usage(): string {
  return `
Usage:
  ${SCRIPT_NAME} <commit-message-file>

Spell-checks a commit message with cspell, using this repo's existing
dictionary (.vscode/dictionary.txt). Strips git's comment lines (and
everything below the "git commit -v" cut line) before checking, so
diff/status output never gets spell-checked.

Run manually against the last commit:
  git log -1 --format=%B > /tmp/msg.txt && node --experimental-strip-types scripts/lint-commit-message.ts /tmp/msg.txt

If a word is flagged incorrectly, add it to .vscode/dictionary.txt (one
word per line, alphabetical) rather than working around the check.
`.trim();
}

function stripCommentsAndCutLine(rawMessage: string): string {
  const lines = rawMessage.split("\n");
  const cutIndex = lines.indexOf(CUT_LINE);
  const relevantLines = cutIndex === -1 ? lines : lines.slice(0, cutIndex);
  return relevantLines.filter((line) => !line.startsWith("#")).join("\n");
}

async function runCspellOnStdin(text: string): Promise<number> {
  return new Promise((resolve, reject) => {
    const cspellBin = path.join(
      process.cwd(),
      "node_modules",
      ".bin",
      "cspell",
    );
    const child = spawn(cspellBin, ["stdin", "--no-progress", "--no-summary"], {
      stdio: ["pipe", "inherit", "inherit"],
    });

    child.on("error", (error: Error) => {
      reject(error);
    });

    child.on("close", (code: number | null) => {
      resolve(code ?? 1);
    });

    child.stdin.end(text);
  });
}

async function main(): Promise<void> {
  const messageFilePath = process.argv[2];

  if (!messageFilePath || messageFilePath === "--help") {
    console.log(usage());
    process.exitCode = messageFilePath === "--help" ? 0 : 1;
    return;
  }

  const rawMessage = await readFile(messageFilePath, "utf8");
  const cleanedMessage = stripCommentsAndCutLine(rawMessage);

  if (cleanedMessage.trim() === "") {
    return;
  }

  const exitCode = await runCspellOnStdin(cleanedMessage);

  if (exitCode !== 0) {
    console.error(
      "\nCommit message spell check failed. If a flagged word is correct, add it to .vscode/dictionary.txt.",
    );
  }

  process.exitCode = exitCode;
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`${SCRIPT_NAME}: ${message}`);
  process.exitCode = 1;
});
