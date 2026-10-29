#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";

const DAY_MS = 24 * 60 * 60 * 1000;

function showHelp() {
  console.log(`
Mailbox quota history analyser

Reads the history file written by monitor-mailboxes.mjs and shows how the
space usage of each mailbox changed over time. It does not connect to the
mail server.

Options:
  --file FILE        History file. Default: MAILBOX_MONITOR_HISTORY_FILE, or
                     data/history.jsonl beside this script
  --mailbox TEXT     Show only mailboxes that contain TEXT.
  --days N           Use only checks of the last N days.
  --series           Show every check of each mailbox, not only the summary.
  --json             Print the result as JSON.
  --help             Show this help.
`);
}

function expandHome(inputPath) {
  return inputPath.startsWith("~")
    ? path.join(os.homedir(), inputPath.slice(1))
    : inputPath;
}

function defaultHistoryFile() {
  const fromEnv = process.env.MAILBOX_MONITOR_HISTORY_FILE?.trim();

  if (fromEnv) {
    return expandHome(fromEnv);
  }

  return path.join(
    path.dirname(fileURLToPath(import.meta.url)),
    "data",
    "history.jsonl",
  );
}

function formatSize(kb) {
  const sign = kb < 0 ? "-" : "";
  const value = Math.abs(kb);
  return value >= 1024 * 1024
    ? `${sign}${(value / 1024 / 1024).toFixed(2)} GB`
    : `${sign}${(value / 1024).toFixed(2)} MB`;
}

async function readHistory(file) {
  let text;

  try {
    text = await readFile(file, "utf8");
  } catch (error) {
    throw new Error(
      `Cannot read history file ${file}: ${error.message}. Run the monitor first or use --file FILE.`,
    );
  }

  const entries = [];

  text.split("\n").forEach((line, index) => {
    if (line.trim() === "") {
      return;
    }

    try {
      const entry = JSON.parse(line);
      const time = Date.parse(entry.checkedAt);

      if (
        !entry.mailbox ||
        !Number.isFinite(entry.usedKb) ||
        !Number.isFinite(time)
      ) {
        throw new Error("missing fields");
      }

      entries.push({ ...entry, time });
    } catch (error) {
      console.warn(`Skipped line ${index + 1} of ${file}: ${error.message}`);
    }
  });

  return entries;
}

function analyse(entries) {
  const byMailbox = new Map();

  for (const entry of entries) {
    if (!byMailbox.has(entry.mailbox)) {
      byMailbox.set(entry.mailbox, []);
    }
    byMailbox.get(entry.mailbox).push(entry);
  }

  const results = [];

  for (const [mailbox, checks] of byMailbox) {
    checks.sort((a, b) => a.time - b.time);
    const first = checks[0];
    const last = checks.at(-1);
    const spanDays = (last.time - first.time) / DAY_MS;
    const changeKb = last.usedKb - first.usedKb;
    const kbPerDay = spanDays > 0 ? changeKb / spanDays : null;
    const limitKb = Number.isFinite(last.limitKb) ? last.limitKb : null;
    const daysUntilFull =
      limitKb !== null && kbPerDay !== null && kbPerDay > 0
        ? Math.max(0, (limitKb - last.usedKb) / kbPerDay)
        : null;

    results.push({
      mailbox,
      checks: checks.length,
      firstCheckedAt: first.checkedAt,
      lastCheckedAt: last.checkedAt,
      firstUsedKb: first.usedKb,
      lastUsedKb: last.usedKb,
      limitKb,
      percent: limitKb
        ? Number(((last.usedKb / limitKb) * 100).toFixed(2))
        : null,
      changeKb,
      kbPerDay: kbPerDay === null ? null : Number(kbPerDay.toFixed(2)),
      daysUntilFull: daysUntilFull === null ? null : Math.round(daysUntilFull),
      series: checks.map(({ checkedAt, usedKb, limitKb: limit }) => ({
        checkedAt,
        usedKb,
        limitKb: limit,
      })),
    });
  }

  // Mailboxes that fill up soonest first, then by current usage.
  return results.sort(
    (a, b) =>
      (a.daysUntilFull ?? Infinity) - (b.daysUntilFull ?? Infinity) ||
      (b.percent ?? 0) - (a.percent ?? 0),
  );
}

function printTable(results, showSeries) {
  const rows = results.map((result) => [
    result.mailbox,
    String(result.checks),
    result.lastCheckedAt.slice(0, 10),
    formatSize(result.lastUsedKb),
    result.limitKb ? formatSize(result.limitKb) : "unlimited",
    result.percent === null ? "-" : `${result.percent.toFixed(2)}%`,
    `${result.changeKb >= 0 ? "+" : ""}${formatSize(result.changeKb)}`,
    result.kbPerDay === null ? "-" : `${formatSize(result.kbPerDay)}/day`,
    result.daysUntilFull === null ? "-" : `${result.daysUntilFull} days`,
  ]);
  const header = [
    "Mailbox",
    "Checks",
    "Last check",
    "Used",
    "Limit",
    "Percent",
    "Change",
    "Rate",
    "Full in",
  ];
  const widths = header.map((title, column) =>
    Math.max(title.length, ...rows.map((row) => row[column].length)),
  );
  const format = (row) =>
    row
      .map((cell, column) =>
        column === 0
          ? cell.padEnd(widths[column])
          : cell.padStart(widths[column]),
      )
      .join("  ");

  console.log(format(header));
  console.log(widths.map((width) => "-".repeat(width)).join("  "));

  for (const [index, row] of rows.entries()) {
    console.log(format(row));

    if (showSeries) {
      for (const point of results[index].series) {
        console.log(`    ${point.checkedAt}  ${formatSize(point.usedKb)}`);
      }
    }
  }
}

async function run() {
  const { values } = parseArgs({
    options: {
      file: { type: "string" },
      mailbox: { type: "string" },
      days: { type: "string" },
      series: { type: "boolean", default: false },
      json: { type: "boolean", default: false },
      help: { type: "boolean", short: "h", default: false },
    },
  });

  if (values.help) {
    showHelp();
    return;
  }

  const file = values.file ? expandHome(values.file) : defaultHistoryFile();
  let entries = await readHistory(file);

  if (values.days !== undefined) {
    const days = Number(values.days);

    if (!Number.isFinite(days) || days <= 0) {
      throw new Error(`Invalid --days value: ${values.days}`);
    }

    const since = Date.now() - days * DAY_MS;
    entries = entries.filter((entry) => entry.time >= since);
  }

  if (values.mailbox) {
    entries = entries.filter((entry) => entry.mailbox.includes(values.mailbox));
  }

  const results = analyse(entries);

  if (values.json) {
    console.log(JSON.stringify(results, null, 2));
    return;
  }

  if (results.length === 0) {
    console.log(`No matching history entries in ${file}.`);
    return;
  }

  printTable(results, values.series);
}

run().catch((error) => {
  console.error("Mailbox history analysis failed.");
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 2;
});
