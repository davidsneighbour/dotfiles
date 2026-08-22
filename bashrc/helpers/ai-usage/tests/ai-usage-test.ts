import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import type { CommandResult } from "../src/commands/run-command.ts";
import { CodexProvider, getDoctorState } from "../src/providers/codex.ts";
import { parseProviderOutput } from "../src/providers/provider.ts";
import { renderTerminalReport, stripAnsi } from "../src/renderers/terminal.ts";
import type { HealthThresholds, UsageLimit } from "../src/types.ts";
import { classifyLimitHealth } from "../src/usage/health.ts";

const dirname = fileURLToPath(new URL(".", import.meta.url));
const thresholds: HealthThresholds = {
  warningRatio: 1.15,
  criticalRatio: 1.35,
  criticalRemainingPercent: 10,
  minimumElapsedPercent: 10,
};

function windowedLimit(usedPercent: number): UsageLimit {
  return {
    id: "5-hour",
    label: "5-hour",
    usedPercent,
    remainingPercent: 100 - usedPercent,
    window: {
      type: "rolling",
      startedAt: "2026-08-20T08:00:00.000Z",
      resetsAt: "2026-08-20T13:00:00.000Z",
    },
  };
}

function weeklyLimit(usedPercent: number): UsageLimit {
  return {
    id: "weekly",
    label: "weekly",
    usedPercent,
    remainingPercent: 100 - usedPercent,
    window: {
      type: "calendar",
      startedAt: "2026-08-17T00:00:00.000Z",
      resetsAt: "2026-08-24T00:00:00.000Z",
    },
  };
}

function commandResult(overrides: Partial<CommandResult>): CommandResult {
  return {
    ok: true,
    command: "codex",
    args: [],
    stdout: "",
    stderr: "",
    timedOut: false,
    ...overrides,
  };
}

const claudeFixture = await readFile(
  join(dirname, "fixtures", "claude", "usage.json"),
  "utf8",
);
const claudeLimits = parseProviderOutput(claudeFixture);
assert.equal(claudeLimits.length, 2);
assert.equal(claudeLimits[0]?.label, "5-hour");
assert.equal(claudeLimits[0]?.usedPercent, 60);
assert.equal(claudeLimits[1]?.window?.type, "calendar");

const codexFixture = await readFile(
  join(dirname, "fixtures", "codex", "status.txt"),
  "utf8",
);
const codexLimits = parseProviderOutput(codexFixture);
assert.equal(codexLimits.length, 2);
assert.equal(codexLimits[0]?.usedPercent, 23);
assert.equal(codexLimits[1]?.label, "weekly");

const claudeJsonResultLimits = parseProviderOutput(
  JSON.stringify({
    result:
      "Current session: 100% used · resets Aug 20, 4pm (Asia/Bangkok)\nCurrent week (all models): 57% used · resets Aug 21, 3pm (Asia/Bangkok)",
  }),
);
const fixtureYear = new Date().getFullYear();
assert.equal(claudeJsonResultLimits.length, 2);
assert.equal(claudeJsonResultLimits[0]?.label, "session");
assert.equal(claudeJsonResultLimits[0]?.usedPercent, 100);
assert.equal(
  claudeJsonResultLimits[0]?.window?.resetsAt,
  `${fixtureYear}-08-20T09:00:00.000Z`,
);
assert.equal(claudeJsonResultLimits[1]?.label, "weekly");
assert.equal(claudeJsonResultLimits[1]?.usedPercent, 57);
assert.equal(
  claudeJsonResultLimits[1]?.window?.resetsAt,
  `${fixtureYear}-08-21T08:00:00.000Z`,
);

// Claude's /usage text only reports a reset time, not a window start. The
// parser must derive startedAt from the known 5-hour/weekly window
// durations so pace-based health scoring can run instead of falling back to
// absolute-only classification for every Claude limit.
assert.equal(claudeJsonResultLimits[0]?.window?.durationSeconds, 5 * 3_600);
assert.equal(
  claudeJsonResultLimits[0]?.window?.startedAt,
  `${fixtureYear}-08-20T04:00:00.000Z`,
);
assert.equal(claudeJsonResultLimits[1]?.window?.durationSeconds, 7 * 86_400);
assert.equal(
  claudeJsonResultLimits[1]?.window?.startedAt,
  `${fixtureYear}-08-14T08:00:00.000Z`,
);

const onPace = classifyLimitHealth(
  windowedLimit(60),
  thresholds,
  new Date("2026-08-20T11:00:00.000Z"),
);
assert.equal(onPace.status, "healthy");
assert.equal(onPace.basis, "pace");

const slightlyAhead = classifyLimitHealth(
  windowedLimit(75),
  thresholds,
  new Date("2026-08-20T11:00:00.000Z"),
);
assert.equal(slightlyAhead.status, "elevated");

const significantlyAhead = classifyLimitHealth(
  windowedLimit(85),
  thresholds,
  new Date("2026-08-20T11:00:00.000Z"),
);
assert.equal(significantlyAhead.status, "critical");

const earlyWindow = classifyLimitHealth(
  {
    ...windowedLimit(5),
    remainingPercent: 95,
  },
  thresholds,
  new Date("2026-08-20T08:05:00.000Z"),
);
assert.equal(earlyWindow.status, "healthy");
assert.equal(earlyWindow.basis, "absolute");

const lowRemaining = classifyLimitHealth(
  {
    ...windowedLimit(91),
    remainingPercent: 9,
  },
  thresholds,
  new Date("2026-08-20T12:45:00.000Z"),
);
assert.equal(lowRemaining.status, "critical");
assert.equal(lowRemaining.basis, "absolute");

// Regression: `claude --output-format json` can leak an unrelated MCP
// diagnostic line onto stdout after the JSON payload (observed live as
// "Client.listTools() called but server does not advertise tools
// capability - returning empty list"). That trailing noise must not break
// JSON parsing and fall through to scanning the raw envelope as text, which
// previously misread every unrelated percentage in the /usage "What's
// contributing to your limits usage?" breakdown (skill/MCP/context stats)
// as bogus extra quota windows.
const claudeOutputWithTrailingNoise = [
  JSON.stringify({
    result:
      "You are currently using your subscription to power your Claude Code usage\n\n" +
      "Current session: 4% used · resets Aug 22, 7:59pm (Asia/Bangkok)\n" +
      "Current week (all models): 2% used · resets Aug 28, 2:59pm (Asia/Bangkok)\n\n" +
      "What's contributing to your limits usage?\n" +
      "Last 24h · 135 requests · 4 sessions\n" +
      "  Top skills: /ksc-dropbox-setup 5%\n" +
      "  Top MCP servers: plugin:playwright:playwright 19%\n" +
      "Last 7d · 3804 requests · 124 sessions\n" +
      "  57% of your usage was at >150k context\n" +
      "  Top skills: /dnb-work-on-issue 32%, /dnb-dependency-maintenance 2%",
  }),
  "Client.listTools() called but server does not advertise tools capability - returning empty list",
].join("\n");
const noiseTolerantLimits = parseProviderOutput(claudeOutputWithTrailingNoise);
assert.equal(noiseTolerantLimits.length, 2);
assert.equal(noiseTolerantLimits[0]?.label, "session");
assert.equal(noiseTolerantLimits[0]?.usedPercent, 4);
assert.equal(noiseTolerantLimits[1]?.label, "weekly");
assert.equal(noiseTolerantLimits[1]?.usedPercent, 2);

// Regression: Claude reports reset times both as a whole hour ("resets Aug
// 20, 4pm") and, observed live, with minutes ("resets Aug 22, 7:59pm"). The
// minutes form previously failed to match and silently dropped resetsAt.
const claudeMinuteResetLimits = parseProviderOutput(
  JSON.stringify({
    result:
      "Current session: 5% used · resets Aug 22, 7:59pm (Asia/Bangkok)\nCurrent week (all models): 2% used · resets Aug 28, 2:59pm (Asia/Bangkok)",
  }),
);
assert.equal(
  claudeMinuteResetLimits[0]?.window?.resetsAt,
  `${fixtureYear}-08-22T12:59:00.000Z`,
);
assert.equal(
  claudeMinuteResetLimits[1]?.window?.resetsAt,
  `${fixtureYear}-08-28T07:59:00.000Z`,
);

// Weekly window boundary tests, mirroring the 5-hour cases above but over a
// 7-day window (4 days elapsed of 7 = ~57% elapsed).
const weeklyOnPace = classifyLimitHealth(
  weeklyLimit(57),
  thresholds,
  new Date("2026-08-21T00:00:00.000Z"),
);
assert.equal(weeklyOnPace.status, "healthy");
assert.equal(weeklyOnPace.basis, "pace");

const weeklySlightlyAhead = classifyLimitHealth(
  weeklyLimit(70),
  thresholds,
  new Date("2026-08-21T00:00:00.000Z"),
);
assert.equal(weeklySlightlyAhead.status, "elevated");

const weeklyCriticallyAhead = classifyLimitHealth(
  weeklyLimit(85),
  thresholds,
  new Date("2026-08-21T00:00:00.000Z"),
);
assert.equal(weeklyCriticallyAhead.status, "critical");

// A reset time that has already passed must not produce a pace score based
// on a negative or zero remaining window; fall back to absolute health.
const resetAlreadyPassed = classifyLimitHealth(
  windowedLimit(80),
  thresholds,
  new Date("2026-08-20T13:30:00.000Z"),
);
assert.equal(resetAlreadyPassed.basis, "absolute");

const unknownStart = classifyLimitHealth(
  {
    id: "weekly",
    label: "weekly",
    usedPercent: 70,
    remainingPercent: 30,
    window: {
      type: "calendar",
      resetsAt: "2026-08-24T00:00:00.000Z",
    },
  },
  thresholds,
);
assert.equal(unknownStart.status, "elevated");
assert.equal(unknownStart.basis, "absolute");

const codexAuthenticatedDoctor = await getDoctorState(async () =>
  commandResult({
    stdout: JSON.stringify({
      checks: {
        "auth.credentials": {
          status: "ok",
          summary: "auth is configured",
        },
      },
    }),
  }),
);
assert.equal(codexAuthenticatedDoctor.authenticated, true);

const codexUnauthenticatedDoctor = await getDoctorState(async () =>
  commandResult({
    stdout: JSON.stringify({
      checks: {
        "auth.credentials": {
          status: "fail",
          summary: "auth is missing",
        },
      },
    }),
  }),
);
assert.equal(codexUnauthenticatedDoctor.authenticated, false);
assert.equal(codexUnauthenticatedDoctor.error, "auth is missing");

const missingCodexProvider = new CodexProvider(
  async () => commandResult({}),
  async () => false,
);
const missingCodex = await missingCodexProvider.collect();
assert.equal(missingCodex.authenticated, false);
assert.equal(missingCodex.error, "codex executable not found");

const unauthenticatedCodexProvider = new CodexProvider(
  async () =>
    commandResult({
      stdout: JSON.stringify({
        checks: {
          "auth.credentials": {
            status: "fail",
            summary: "login required",
          },
        },
      }),
    }),
  async () => true,
);
const unauthenticatedCodex = await unauthenticatedCodexProvider.collect();
assert.equal(unauthenticatedCodex.authenticated, false);
assert.equal(unauthenticatedCodex.error, "login required");

const unsupportedCodexProvider = new CodexProvider(
  async () =>
    commandResult({
      stdout: JSON.stringify({
        checks: {
          "auth.credentials": {
            status: "ok",
          },
        },
      }),
    }),
  async () => true,
);
const unsupportedCodex = await unsupportedCodexProvider.collect();
assert.equal(unsupportedCodex.authenticated, true);
assert.equal(unsupportedCodex.limits.length, 0);
assert.equal(
  unsupportedCodex.error,
  "Codex does not expose a non-interactive usage source yet",
);

const rendered = renderTerminalReport(
  {
    collectedAt: "2026-08-20T08:44:00.000Z",
    providers: [
      {
        provider: "claude",
        displayName: "Claude Code",
        authenticated: true,
        collectedAt: "2026-08-20T08:44:00.000Z",
        limits: [
          {
            id: "session",
            label: "session",
            usedPercent: 100,
            remainingPercent: 0,
            window: { type: "rolling" },
            health: {
              status: "critical",
              basis: "absolute",
              reason: "remaining quota is critically low",
            },
          },
        ],
      },
    ],
    summary: {
      configuredProviders: 1,
      availableProviders: 1,
      criticalLimits: [
        {
          provider: "claude",
          displayName: "Claude Code",
          limitId: "session",
          label: "session",
          remainingPercent: 0,
          usedPercent: 100,
        },
      ],
      lowestRemaining: {
        provider: "claude",
        displayName: "Claude Code",
        limitId: "session",
        label: "session",
        remainingPercent: 0,
        usedPercent: 100,
      },
    },
  },
  { colour: true, now: new Date("2026-08-20T08:44:00.000Z") },
);
const renderedPlain = stripAnsi(rendered);
assert.match(renderedPlain, /session\s+100%\s+0%\s+-\s+-\s+crit critical/);
assert.doesNotMatch(renderedPlain, /100%0%/);

console.log("ai-usage tests passed");
