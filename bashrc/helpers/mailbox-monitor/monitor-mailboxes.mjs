#!/usr/bin/env node

import { mkdir, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { chromium } from "playwright";

const DEFAULTS = {
  yellowThreshold: 80,
  redThreshold: 95,
  headless: true,
  navPath: "Email|Manage Mailboxes",
  rowSelector: ".newui-table-row",
  mailboxSelector: ".col-7",
  usageSelector: ".col-2",
  dataSortUnit: "KB",
  timeoutMs: 30_000,
};

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

Required environment variables:
  MAILBOX_MONITOR_START_URL
  MAILBOX_MONITOR_USERNAME
  MAILBOX_MONITOR_PASSWORD

Optional environment variables:
  DISCORD_WEBHOOK
  MAILBOX_MONITOR_PROJECT_NAME
  MAILBOX_MONITOR_NAV_PATH
  MAILBOX_MONITOR_YELLOW_THRESHOLD
  MAILBOX_MONITOR_RED_THRESHOLD
  MAILBOX_MONITOR_HEADLESS
  MAILBOX_MONITOR_OUTPUT_DIR
  MAILBOX_MONITOR_USERNAME_SELECTOR
  MAILBOX_MONITOR_PASSWORD_SELECTOR
  MAILBOX_MONITOR_LOGIN_SELECTOR
  MAILBOX_MONITOR_ROW_SELECTOR
  MAILBOX_MONITOR_MAILBOX_SELECTOR
  MAILBOX_MONITOR_USAGE_SELECTOR

Example:
  MAILBOX_MONITOR_HEADLESS=false node monitor-mailboxes.mjs
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

function booleanEnv(name, fallback) {
  const raw = optionalEnv(name, String(fallback)).toLowerCase();

  if (["1", "true", "yes", "on"].includes(raw)) {
    return true;
  }

  if (["0", "false", "no", "off"].includes(raw)) {
    return false;
  }

  throw new MonitorError(
    `Invalid boolean environment variable ${name}: ${raw}`,
  );
}

function expandHome(inputPath) {
  if (!inputPath.startsWith("~")) {
    return inputPath;
  }

  return path.join(os.homedir(), inputPath.slice(1));
}

function getConfig() {
  return {
    startUrl: requireEnv("MAILBOX_MONITOR_START_URL"),
    username: requireEnv("MAILBOX_MONITOR_USERNAME"),
    password: requireEnv("MAILBOX_MONITOR_PASSWORD"),
    projectName: optionalEnv("MAILBOX_MONITOR_PROJECT_NAME", "Mailbox Monitor"),
    discordWebhook: optionalEnv("DISCORD_WEBHOOK", ""),
    navPath: optionalEnv("MAILBOX_MONITOR_NAV_PATH", DEFAULTS.navPath),
    yellowThreshold: numberEnv(
      "MAILBOX_MONITOR_YELLOW_THRESHOLD",
      DEFAULTS.yellowThreshold,
    ),
    redThreshold: numberEnv(
      "MAILBOX_MONITOR_RED_THRESHOLD",
      DEFAULTS.redThreshold,
    ),
    headless: booleanEnv("MAILBOX_MONITOR_HEADLESS", DEFAULTS.headless),
    outputDir: expandHome(
      optionalEnv("MAILBOX_MONITOR_OUTPUT_DIR", "~/.logs/mailbox-monitor"),
    ),
    usernameSelector: optionalEnv("MAILBOX_MONITOR_USERNAME_SELECTOR", ""),
    passwordSelector: optionalEnv("MAILBOX_MONITOR_PASSWORD_SELECTOR", ""),
    loginSelector: optionalEnv("MAILBOX_MONITOR_LOGIN_SELECTOR", ""),
    rowSelector: optionalEnv(
      "MAILBOX_MONITOR_ROW_SELECTOR",
      DEFAULTS.rowSelector,
    ),
    mailboxSelector: optionalEnv(
      "MAILBOX_MONITOR_MAILBOX_SELECTOR",
      DEFAULTS.mailboxSelector,
    ),
    usageSelector: optionalEnv(
      "MAILBOX_MONITOR_USAGE_SELECTOR",
      DEFAULTS.usageSelector,
    ),
    dataSortUnit: optionalEnv(
      "MAILBOX_MONITOR_DATA_SORT_UNIT",
      DEFAULTS.dataSortUnit,
    ),
    timeoutMs: numberEnv("MAILBOX_MONITOR_TIMEOUT_MS", DEFAULTS.timeoutMs),
  };
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

async function firstVisibleLocator(locators, label) {
  for (const locator of locators) {
    try {
      const first = locator.first();
      await first.waitFor({ state: "visible", timeout: 1_500 });
      return first;
    } catch {
      // Try next candidate.
    }
  }

  throw new MonitorError(`Could not find visible element for: ${label}`);
}

async function fillFirstVisible(
  page,
  explicitSelector,
  fallbackLocators,
  value,
  label,
) {
  const locators = explicitSelector
    ? [page.locator(explicitSelector)]
    : fallbackLocators;

  const locator = await firstVisibleLocator(locators, label);
  await locator.fill(value);
}

async function clickFirstVisible(
  page,
  explicitSelector,
  fallbackLocators,
  label,
) {
  const locators = explicitSelector
    ? [page.locator(explicitSelector)]
    : fallbackLocators;

  const locator = await firstVisibleLocator(locators, label);
  await locator.click();
}

async function waitAfterNavigationAction(page) {
  await runBestEffort("domcontentloaded wait", () =>
    page.waitForLoadState("domcontentloaded", { timeout: 15_000 }),
  );
  await runBestEffort("networkidle wait", () =>
    page.waitForLoadState("networkidle", { timeout: 10_000 }),
  );
}

async function login(page, config) {
  await page.goto(config.startUrl, {
    waitUntil: "domcontentloaded",
    timeout: config.timeoutMs,
  });

  await fillFirstVisible(
    page,
    config.usernameSelector,
    [
      page.locator('input[name="username"]'),
      page.locator('input[name="user"]'),
      page.locator('input[name="login"]'),
      page.locator('input[name="account"]'),
      page.locator('input[type="email"]'),
      page.locator('input[type="text"]'),
      page.getByLabel(/user|username|account|login/i),
    ],
    config.username,
    "username field",
  );

  await fillFirstVisible(
    page,
    config.passwordSelector,
    [
      page.locator('input[name="password"]'),
      page.locator('input[type="password"]'),
      page.getByLabel(/password/i),
    ],
    config.password,
    "password field",
  );

  await clickFirstVisible(
    page,
    config.loginSelector,
    [
      page.getByRole("button", { name: /log in|login|sign in|submit/i }),
      page.getByRole("link", { name: /log in|login|sign in|submit/i }),
      page.locator('button[type="submit"]'),
      page.locator('input[type="submit"]'),
    ],
    "login button",
  );

  await waitAfterNavigationAction(page);
}

function cssAttributeValue(value) {
  return JSON.stringify(value);
}

async function clickNavigationPath(page, navPath) {
  const labels = navPath
    .split("|")
    .map((label) => label.trim())
    .filter(Boolean);

  for (const label of labels) {
    const exactLabel = new RegExp(`^\\s*${escapeRegExp(label)}\\s*$`, "i");
    const cssLabel = cssAttributeValue(label);

    await clickFirstVisible(
      page,
      "",
      [
        page.getByRole("link", { name: exactLabel }),
        page.getByRole("button", { name: exactLabel }),

        page.locator(`a[data-bs-title=${cssLabel}]`),
        page.locator(`button[data-bs-title=${cssLabel}]`),
        page.locator(`[data-bs-title=${cssLabel}]`),

        page.locator(`a[title=${cssLabel}]`),
        page.locator(`button[title=${cssLabel}]`),
        page.locator(`[title=${cssLabel}]`),

        page.locator(`a[aria-label=${cssLabel}]`),
        page.locator(`button[aria-label=${cssLabel}]`),
        page.locator(`[aria-label=${cssLabel}]`),

        page.locator("a", { hasText: label }),
        page.locator("button", { hasText: label }),
      ],
      `navigation item "${label}"`,
    );

    await waitAfterNavigationAction(page);
  }
}

function unitToMb(value, unitRaw) {
  const unit = String(unitRaw || "M")
    .trim()
    .toUpperCase()
    .replace(/B$/, "");

  switch (unit) {
    case "K":
      return value / 1024;
    case "M":
    case "":
      return value;
    case "G":
      return value * 1024;
    case "T":
      return value * 1024 * 1024;
    default:
      throw new MonitorError(`Unsupported size unit: ${unitRaw}`);
  }
}

function parseDataSortToMb(dataSort, unitRaw) {
  if (!dataSort) {
    return undefined;
  }

  const value = Number(dataSort);

  if (!Number.isFinite(value)) {
    return undefined;
  }

  return unitToMb(value, unitRaw);
}

function parseMailboxUsage(rawRow, config) {
  const usageText = rawRow.usageText.replace(/\s+/g, " ").trim();

  const usedTextMatch = usageText.match(/^([\d.]+)\s*(KB|MB|GB|TB|K|M|G|T)\b/i);
  const limitMatch = usageText.match(/\/\s*([\d.]+)\s*([KMGT]?B?|[KMGT])?/i);

  if (!limitMatch) {
    throw new MonitorError(
      `Could not parse quota limit for ${rawRow.mailbox}: "${usageText}"`,
    );
  }

  const usedMbFromDataSort = parseDataSortToMb(
    rawRow.dataSort,
    config.dataSortUnit,
  );

  if (usedMbFromDataSort === undefined && !usedTextMatch) {
    throw new MonitorError(
      `Could not parse used quota for ${rawRow.mailbox}: "${usageText}"`,
    );
  }

  const usedMb =
    usedMbFromDataSort === undefined
      ? unitToMb(Number(usedTextMatch[1]), usedTextMatch[2])
      : usedMbFromDataSort;

  const limitMb = unitToMb(Number(limitMatch[1]), limitMatch[2] || "M");
  const percent = limitMb > 0 ? (usedMb / limitMb) * 100 : 0;

  const status =
    percent >= config.redThreshold
      ? "red"
      : percent >= config.yellowThreshold
        ? "yellow"
        : "green";

  return {
    mailbox: rawRow.mailbox,
    usageText,
    usedMb,
    limitMb,
    percent: Number(percent.toFixed(2)),
    status,
  };
}

async function extractRawRows(page, config) {
  await page.locator(config.rowSelector).first().waitFor({
    state: "visible",
    timeout: config.timeoutMs,
  });

  const result = await page.locator(config.rowSelector).evaluateAll(
    (rows, selectors) => {
      const normalize = (value) =>
        String(value || "")
          .replace(/\u00a0/g, " ")
          .replace(/\s+/g, " ")
          .trim();

      const pickCell = (row, explicitSelector, fallbackIndex) => {
        const explicitCell = explicitSelector
          ? row.querySelector(explicitSelector)
          : null;

        if (explicitCell) {
          return explicitCell;
        }

        const directCells = Array.from(row.children).filter((child) => {
          const tag = child.tagName.toLowerCase();
          return tag === "td" || tag === "div";
        });

        return directCells[fallbackIndex] || null;
      };

      const parsedRows = rows.map((row) => {
        const mailboxCell = pickCell(row, selectors.mailboxSelector, 0);
        const usageCell = pickCell(row, selectors.usageSelector, 1);

        return {
          mailbox: normalize(mailboxCell?.textContent),
          usageText: normalize(usageCell?.textContent),
          dataSort: normalize(usageCell?.getAttribute("data-sort")),
        };
      });

      return {
        rowCount: rows.length,
        parsedRows,
      };
    },
    {
      mailboxSelector: config.mailboxSelector,
      usageSelector: config.usageSelector,
    },
  );

  const rawRows = result.parsedRows.filter(
    (row) => row.mailbox && row.usageText,
  );

  if (result.rowCount > 0 && rawRows.length === 0) {
    throw new MonitorError(
      `Found ${result.rowCount} mailbox table rows, but parsed 0 usable rows. The table markup probably changed.`,
    );
  }

  if (rawRows.length === 0) {
    throw new MonitorError(
      "No mailbox rows were parsed from the mailbox table.",
    );
  }

  return rawRows;
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

async function writeOutputs(config, allRecords, alertRecords, page) {
  await mkdir(config.outputDir, { recursive: true });

  const html = await page.content();
  const summary = createMarkdownSummary(config, allRecords, alertRecords);

  await writeFile(
    path.join(config.outputDir, "latest-mailboxes.html"),
    html,
    "utf8",
  );

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
    summary,
    "utf8",
  );
}

async function run() {
  if (process.argv.includes("--help") || process.argv.includes("-h")) {
    showHelp();
    return;
  }

  const config = getConfig();
  delete process.env.MAILBOX_MONITOR_PASSWORD;
  delete process.env.MAILBOX_MONITOR_USERNAME;

  let browser;
  let page;

  try {
    browser = await chromium.launch({
      headless: config.headless,
      env: {
        HOME: process.env.HOME || "",
        PATH: process.env.PATH || "",
        LANG: process.env.LANG || "C.UTF-8",
        XDG_RUNTIME_DIR: process.env.XDG_RUNTIME_DIR || "",
      },
    });
    page = await browser.newPage();

    page.setDefaultTimeout(config.timeoutMs);

    await login(page, config);
    config.password = "";

    if (config.navPath) {
      await clickNavigationPath(page, config.navPath);
    }

    const rawRows = await extractRawRows(page, config);
    const allRecords = rawRows
      .map((row) => parseMailboxUsage(row, config))
      .sort((a, b) => b.percent - a.percent);

    const alertRecords = allRecords.filter(
      (record) => record.percent >= config.yellowThreshold,
    );

    await writeOutputs(config, allRecords, alertRecords, page);

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

    for (const record of alertRecords) {
      console.log(
        `${record.status.toUpperCase()} ${record.percent.toFixed(2)}% ${record.mailbox} ${record.usageText}`,
      );
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);

    if (page) {
      await runBestEffort("error output directory creation", () =>
        mkdir(config.outputDir, { recursive: true }),
      );
      await runBestEffort("error screenshot capture", () =>
        page.screenshot({
          path: path.join(config.outputDir, "latest-error.png"),
          fullPage: true,
        }),
      );
    }

    if (config.discordWebhook) {
      await runBestEffort("Discord failure notification", () =>
        sendDiscordMessage(
          config.discordWebhook,
          `:warning: **${config.projectName}: mailbox monitor failed**\n${message}`,
        ),
      );
    }

    throw error;
  } finally {
    if (browser) {
      await runBestEffort("browser close", () => browser.close());
    }
  }
}

run().catch((error) => {
  console.error("Mailbox monitor failed.");

  if (error instanceof Error) {
    console.error(error.message);

    if (error.cause) {
      console.error(error.cause);
    }
  } else {
    console.error(error);
  }

  process.exitCode = 2;
});
