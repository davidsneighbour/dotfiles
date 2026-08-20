import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
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
