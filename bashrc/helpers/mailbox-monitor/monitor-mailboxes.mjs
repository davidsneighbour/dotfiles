#!/usr/bin/env node

import { execFile } from "node:child_process";
import { appendFile, mkdir, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

const DEFAULTS = {
  yellowThreshold: 80,
  redThreshold: 95,
  sshKey: "~/.ssh/id_ed25519",
  timeoutMs: 120_000,
};

// Runs on the mail server with /bin/sh. Arguments: boxes directory, then
// optional domain names. Without domains, every domain directory is checked.
// Each mailbox is a regular file in a domain directory (mbox INBOX); Dovecot
// reports its quota in KB including the folders in the matching "name^"
// directory.
const REMOTE_SCRIPT = String.raw`
boxes="$1"
shift
cd "$boxes" || exit 3
if [ "$#" -eq 0 ]; then
  for candidate in *.*; do
    [ -d "$candidate" ] && set -- "$@" "$candidate"
  done
fi
for domain in "$@"; do
  if [ ! -d "$domain" ]; then
    printf 'ERROR\t%s\t%s\n' "$domain" "domain directory not found"
    continue
  fi
  for file in "$domain"/*; do
    [ -f "$file" ] || continue
    user="$(basename "$file")@$domain"
    output="$(doveadm -f tab quota get -u "$user" 2>&1)"
    quota="$(printf '%s\n' "$output" | awk -F '\t' '$2 == "STORAGE" { print $3 "\t" $4; exit }')"
    if [ -n "$quota" ]; then
      printf 'OK\t%s\t%s\n' "$user" "$quota"
    elif printf '%s\n' "$output" | grep -q "User doesn't exist"; then
      # Leftover mailbox file of a deleted account.
      printf 'SKIP\t%s\t%s\n' "$user" "no mail account for this file"
    else
      printf 'ERROR\t%s\t%s\n' "$user" "no storage quota reported"
    fi
  done
done
`;

class MonitorError extends Error {
  constructor(message, cause = undefined) {
    super(message);
    this.name = "MonitorError";
    this.cause = cause;
  }
}

async function runBestEffort(label, operation) {
  try {
    await operation();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(`Best-effort ${label} failed: ${message}`);
  }
}

function showHelp() {
  console.log(`
Mailbox quota monitor

Reads mailbox quotas over SSH with doveadm on the mail server.

Required environment variables:
  MAILBOX_MONITOR_SSH_TARGET   (example: user@host.pair.com)
  MAILBOX_MONITOR_BOXES_DIR    (example: /usr/boxes/user)

Optional environment variables:
  MAILBOX_MONITOR_SSH_KEY      (default: ~/.ssh/id_ed25519)
  MAILBOX_MONITOR_DOMAINS      (comma-separated; default: all domain directories)
  MAILBOX_MONITOR_PROJECT_NAME
  MAILBOX_MONITOR_YELLOW_THRESHOLD
  MAILBOX_MONITOR_RED_THRESHOLD
  MAILBOX_MONITOR_OUTPUT_DIR
  MAILBOX_MONITOR_HISTORY_FILE (default: <output dir>/history.jsonl)
  MAILBOX_MONITOR_TIMEOUT_MS
  DISCORD_WEBHOOK

Options:
  --help     Show this help.
`);
}

function requireEnv(name) {
  const value = process.env[name];

  if (!value || value.trim() === "") {
    throw new MonitorError(`Missing required environment variable: ${name}`);
  }

  return value.trim();
}

function optionalEnv(name, fallback) {
  const value = process.env[name];
  return value && value.trim() !== "" ? value.trim() : fallback;
}

function numberEnv(name, fallback) {
  const raw = optionalEnv(name, String(fallback));
  const value = Number(raw);

  if (!Number.isFinite(value)) {
    throw new MonitorError(
      `Invalid numeric environment variable ${name}: ${raw}`,
    );
  }

  return value;
}

function expandHome(inputPath) {
  if (!inputPath.startsWith("~")) {
    return inputPath;
  }

  return path.join(os.homedir(), inputPath.slice(1));
}

function safeRemoteArgument(name, value) {
  if (!/^[A-Za-z0-9._/@-]+$/.test(value)) {
    throw new MonitorError(`${name} contains unsupported characters: ${value}`);
  }

  return value;
}

function getConfig() {
  const outputDir = expandHome(
    optionalEnv("MAILBOX_MONITOR_OUTPUT_DIR", "~/.logs/mailbox-monitor"),
  );

  const domains = optionalEnv("MAILBOX_MONITOR_DOMAINS", "")
    .split(",")
    .map((domain) => domain.trim())
    .filter(Boolean)
    .map((domain) => safeRemoteArgument("MAILBOX_MONITOR_DOMAINS", domain));

  return {
    sshTarget: requireEnv("MAILBOX_MONITOR_SSH_TARGET"),
    sshKey: expandHome(optionalEnv("MAILBOX_MONITOR_SSH_KEY", DEFAULTS.sshKey)),
    boxesDir: safeRemoteArgument(
      "MAILBOX_MONITOR_BOXES_DIR",
      requireEnv("MAILBOX_MONITOR_BOXES_DIR"),
    ),
    domains,
    projectName: optionalEnv("MAILBOX_MONITOR_PROJECT_NAME", "Mailbox Monitor"),
    discordWebhook: optionalEnv("DISCORD_WEBHOOK", ""),
    yellowThreshold: numberEnv(
      "MAILBOX_MONITOR_YELLOW_THRESHOLD",
      DEFAULTS.yellowThreshold,
    ),
    redThreshold: numberEnv(
      "MAILBOX_MONITOR_RED_THRESHOLD",
      DEFAULTS.redThreshold,
    ),
    outputDir,
    historyFile: expandHome(
      optionalEnv(
        "MAILBOX_MONITOR_HISTORY_FILE",
        path.join(outputDir, "history.jsonl"),
      ),
    ),
    timeoutMs: numberEnv("MAILBOX_MONITOR_TIMEOUT_MS", DEFAULTS.timeoutMs),
  };
}

async function readRemoteQuotas(config) {
  // The remote login shell can be csh, so the script is passed on stdin to
  // sh, and the remote command contains only validated plain arguments.
  const remoteCommand = ["sh", "-s", "--", config.boxesDir, ...config.domains]
    .map((argument) => `'${argument}'`)
    .join(" ");

  const child = execFileAsync(
    "ssh",
    [
      "-i",
      config.sshKey,
      "-o",
      "BatchMode=yes",
      "-o",
      "IdentitiesOnly=yes",
      "-o",
      "ConnectTimeout=20",
      config.sshTarget,
      remoteCommand,
    ],
    { timeout: config.timeoutMs, maxBuffer: 10 * 1024 * 1024 },
  );
  child.child.stdin.end(REMOTE_SCRIPT);

  try {
    const { stdout } = await child;
    return stdout;
  } catch (error) {
    const stderr = String(error.stderr || "").trim();
    throw new MonitorError(
      `SSH quota query to ${config.sshTarget} failed${stderr ? `: ${stderr}` : "."} Check the SSH key, host, and MAILBOX_MONITOR_BOXES_DIR.`,
      error,
    );
  }
}

function formatSize(kb) {
  return kb >= 1024 * 1024
    ? `${(kb / 1024 / 1024).toFixed(2)} GB`
    : `${(kb / 1024).toFixed(2)} MB`;
}

function parseRemoteOutput(stdout, config) {
  const records = [];
  const errors = [];

  for (const line of stdout.split("\n")) {
    if (line.trim() === "") {
      continue;
    }

    const [kind, mailbox, ...rest] = line.split("\t");

    if (kind === "ERROR") {
      errors.push(`${mailbox}: ${rest.join(" ")}`);
      continue;
    }

    if (kind === "SKIP") {
      console.warn(`Skipped ${mailbox}: ${rest.join(" ")}`);
      continue;
    }

    const usedKb = Number(rest[0]);
    const limitKb = Number(rest[1]);

    if (kind !== "OK" || !Number.isFinite(usedKb)) {
      errors.push(`Unexpected output: ${line}`);
      continue;
    }

    // doveadm prints "-" as the limit for mailboxes without a quota.
    const hasLimit = Number.isFinite(limitKb) && limitKb > 0;
    const percent = hasLimit ? (usedKb / limitKb) * 100 : 0;

    records.push({
      mailbox,
      usageText: `${formatSize(usedKb)} / ${hasLimit ? formatSize(limitKb) : "unlimited"}`,
      usedKb,
      limitKb: hasLimit ? limitKb : null,
      usedMb: usedKb / 1024,
      limitMb: hasLimit ? limitKb / 1024 : null,
      percent: Number(percent.toFixed(2)),
      status:
        percent >= config.redThreshold
          ? "red"
          : percent >= config.yellowThreshold
            ? "yellow"
            : "green",
    });
  }

  return { records, errors };
}

function createDiscordContent(config, allRecords, alertRecords) {
  const redCount = alertRecords.filter(
    (record) => record.status === "red",
  ).length;
  const yellowCount = alertRecords.filter(
    (record) => record.status === "yellow",
  ).length;

  const lines = [
    `:mailbox_with_mail: **${config.projectName}: mailbox quota warning**`,
    `Flagged: ${alertRecords.length}/${allRecords.length} mailboxes. Red: ${redCount}. Yellow: ${yellowCount}.`,
    "",
  ];

  for (const record of alertRecords) {
    const marker = record.status === "red" ? ":red_circle:" : ":yellow_circle:";
    lines.push(
      `${marker} ${record.percent.toFixed(2)}% - ${record.mailbox} - ${record.usageText}`,
    );
  }

  const content = lines.join("\n");

  if (content.length <= 1900) {
    return content;
  }

  return `${content.slice(0, 1850)}\n\nOutput truncated. Check local JSON output for the full result.`;
}

async function sendDiscordMessage(
  webhookUrl,
  content,
  username = "Mailbox Quota Monitor",
) {
  if (!webhookUrl) {
    return;
  }

  const response = await fetch(webhookUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      username,
      content,
    }),
  });

  if (!response.ok) {
    const responseText = await response.text().catch(() => "");
    throw new MonitorError(
      `Discord webhook failed with HTTP ${response.status}: ${responseText}`,
    );
  }
}

function createMarkdownSummary(config, allRecords, alertRecords) {
  const lines = [
    `# ${config.projectName} mailbox quota report`,
    "",
    `Generated: ${new Date().toISOString()}`,
    `Total mailboxes: ${allRecords.length}`,
    `Flagged mailboxes: ${alertRecords.length}`,
    "",
    "| Status | Mailbox | Usage | Percent |",
    "|---|---|---:|---:|",
  ];

  for (const record of alertRecords) {
    lines.push(
      `| ${record.status} | ${record.mailbox} | ${record.usageText} | ${record.percent.toFixed(2)}% |`,
    );
  }

  return `${lines.join("\n")}\n`;
}

async function writeOutputs(config, allRecords, alertRecords) {
  await mkdir(config.outputDir, { recursive: true });

  await writeFile(
    path.join(config.outputDir, "latest-mailboxes.json"),
    JSON.stringify(allRecords, null, 2),
    "utf8",
  );

  await writeFile(
    path.join(config.outputDir, "latest-alerts.json"),
    JSON.stringify(alertRecords, null, 2),
    "utf8",
  );

  await writeFile(
    path.join(config.outputDir, "latest-summary.md"),
    createMarkdownSummary(config, allRecords, alertRecords),
    "utf8",
  );
}

// Appends one JSON line per mailbox. The file is only ever appended to;
// analyse-history.mjs reads it to show usage over time.
async function appendHistory(config, checkedAt, allRecords) {
  await mkdir(path.dirname(config.historyFile), { recursive: true });

  const lines = allRecords.map((record) =>
    JSON.stringify({
      checkedAt,
      mailbox: record.mailbox,
      usedKb: record.usedKb,
      limitKb: record.limitKb,
    }),
  );

  await appendFile(config.historyFile, `${lines.join("\n")}\n`, "utf8");
}

async function run() {
  if (process.argv.includes("--help") || process.argv.includes("-h")) {
    showHelp();
    return;
  }

  const config = getConfig();

  try {
    const stdout = await readRemoteQuotas(config);
    const checkedAt = new Date().toISOString();
    const { records, errors } = parseRemoteOutput(stdout, config);

    if (errors.length > 0) {
      throw new MonitorError(
        `Quota query returned errors:\n${errors.join("\n")}`,
      );
    }

    if (records.length === 0) {
      throw new MonitorError(
        `No mailboxes found under ${config.boxesDir}. Check MAILBOX_MONITOR_BOXES_DIR and MAILBOX_MONITOR_DOMAINS.`,
      );
    }

    const allRecords = records.sort((a, b) => b.percent - a.percent);
    const alertRecords = allRecords.filter(
      (record) => record.percent >= config.yellowThreshold,
    );

    await appendHistory(config, checkedAt, allRecords);
    await writeOutputs(config, allRecords, alertRecords);

    if (alertRecords.length > 0 && config.discordWebhook) {
      await sendDiscordMessage(
        config.discordWebhook,
        createDiscordContent(config, allRecords, alertRecords),
      );
    }

    console.log(`Checked ${allRecords.length} mailboxes.`);
    console.log(
      `Flagged ${alertRecords.length} mailboxes at ${config.yellowThreshold}% or more.`,
    );
    console.log(`Output directory: ${config.outputDir}`);
    console.log(`History file: ${config.historyFile}`);

    for (const record of alertRecords) {
      console.log(
        `${record.status.toUpperCase()} ${record.percent.toFixed(2)}% ${record.mailbox} ${record.usageText}`,
      );
    }
  } catch (error) {
    const message =
      error instanceof MonitorError
        ? error.message
        : `Mailbox monitor failed: ${error instanceof Error ? error.message : String(error)}`;

    if (config.discordWebhook) {
      await runBestEffort("Discord failure notification", () =>
        sendDiscordMessage(
          config.discordWebhook,
          `:warning: **${config.projectName}: mailbox monitor failed**\n${message.slice(0, 1800)}`,
        ),
      );
    }

    throw new MonitorError(message, error);
  }
}

run().catch((error) => {
  console.error("Mailbox monitor failed.");

  if (error instanceof Error) {
    console.error(error.message);
  } else {
    console.error(error);
  }

  process.exitCode = 2;
});
