import type {
  HealthStatus,
  UsageLimitWithHealth,
  UsageProviderResultWithHealth,
  UsageReport,
} from "../types.ts";
import { formatDuration, formatResetAt, secondsUntil } from "../usage/time.ts";

interface ColourSet {
  green(value: string): string;
  yellow(value: string): string;
  red(value: string): string;
  dim(value: string): string;
}

const plainColours: ColourSet = {
  green: (value) => value,
  yellow: (value) => value,
  red: (value) => value,
  dim: (value) => value,
};

const ANSI_PATTERN = new RegExp(String.raw`\x1B\[[0-9;]*m`, "g");

export function stripAnsi(value: string): string {
  return value.replace(ANSI_PATTERN, "");
}

function makeColours(enabled: boolean): ColourSet {
  if (!enabled) {
    return plainColours;
  }

  return {
    green: (value) => `\u001b[32m${value}\u001b[0m`,
    yellow: (value) => `\u001b[33m${value}\u001b[0m`,
    red: (value) => `\u001b[31m${value}\u001b[0m`,
    dim: (value) => `\u001b[2m${value}\u001b[0m`,
  };
}

function pad(value: string, width: number): string {
  const visibleLength = stripAnsi(value).length;
  return visibleLength >= width
    ? value
    : `${value}${" ".repeat(width - visibleLength)}`;
}

function pct(value: number | undefined): string {
  return value === undefined ? "-" : `${Math.round(value)}%`;
}

function statusIcon(status: HealthStatus): string {
  switch (status) {
    case "healthy":
      return "ok";
    case "elevated":
      return "warn";
    case "critical":
      return "crit";
    case "unknown":
      return "unk";
  }
}

function colourStatus(
  value: string,
  status: HealthStatus,
  colours: ColourSet,
): string {
  switch (status) {
    case "healthy":
      return colours.green(value);
    case "elevated":
      return colours.yellow(value);
    case "critical":
      return colours.red(value);
    case "unknown":
      return colours.dim(value);
  }
}

function renderLimitRow(
  provider: UsageProviderResultWithHealth,
  limit: UsageLimitWithHealth,
  now: Date,
  colours: ColourSet,
): string {
  const resetIn = secondsUntil(limit.window?.resetsAt, now);
  const status = `${statusIcon(limit.health.status)} ${limit.health.status}`;
  const used = colourStatus(
    pct(limit.usedPercent),
    limit.health.status,
    colours,
  );
  const left = colourStatus(
    pct(limit.remainingPercent),
    limit.health.status,
    colours,
  );

  return [
    pad(provider.displayName, 14),
    pad(limit.label, 12),
    pad(used, 12),
    pad(left, 12),
    pad(formatResetAt(limit.window?.resetsAt, now), 12),
    pad(resetIn === undefined ? "-" : formatDuration(resetIn), 12),
    status,
  ].join("");
}

function renderUnavailableRow(
  provider: UsageProviderResultWithHealth,
  colours: ColourSet,
): string {
  const message = provider.error ?? "unavailable";
  return `${pad(provider.displayName, 14)}${colours.dim(`unavailable - ${message}`)}`;
}

function summaryLine(label: string, value: string): string {
  return `${pad(label, 28)}${value}`;
}

export function renderTerminalReport(
  report: UsageReport,
  options: { colour: boolean; now?: Date },
): string {
  const now = options.now ?? new Date(report.collectedAt);
  const colours = makeColours(options.colour);
  const updated = new Intl.DateTimeFormat(undefined, {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(new Date(report.collectedAt));
  const lines = [
    `AI usage                                      updated ${updated}`,
    "",
  ];
  const hasLimits = report.providers.some(
    (provider) => provider.limits.length > 0,
  );

  if (hasLimits) {
    lines.push(
      [
        pad("SERVICE", 14),
        pad("LIMIT", 12),
        pad("USED", 12),
        pad("LEFT", 12),
        pad("RESETS AT", 12),
        pad("RESETS IN", 12),
        "STATUS",
      ].join(""),
    );
  }

  for (const provider of report.providers) {
    if (provider.limits.length === 0) {
      lines.push(renderUnavailableRow(provider, colours));
      continue;
    }

    for (const limit of provider.limits) {
      lines.push(renderLimitRow(provider, limit, now, colours));
    }
  }

  lines.push(
    "",
    "Overall",
    "------------------------------------------------------------",
  );
  lines.push(
    summaryLine(
      "Services available",
      `${report.summary.availableProviders} / ${report.summary.configuredProviders}`,
    ),
  );
  lines.push(
    summaryLine(
      "Critical limits",
      report.summary.criticalLimits.length === 0
        ? "none"
        : report.summary.criticalLimits
            .map((limit) => `${limit.displayName} ${limit.label}`)
            .join(", "),
    ),
  );
  lines.push(
    summaryLine(
      "Highest pressure",
      report.summary.highestPressure
        ? `${report.summary.highestPressure.displayName} ${report.summary.highestPressure.label}`
        : "-",
    ),
  );
  lines.push(
    summaryLine(
      "Lowest remaining",
      report.summary.lowestRemaining
        ? `${pct(report.summary.lowestRemaining.remainingPercent)} - ${report.summary.lowestRemaining.displayName} ${report.summary.lowestRemaining.label}`
        : "-",
    ),
  );
  lines.push(
    summaryLine(
      "Next reset",
      report.summary.nextReset
        ? `${report.summary.nextReset.displayName} ${report.summary.nextReset.label} - ${formatDuration(
            secondsUntil(report.summary.nextReset.resetsAt, now) ?? 0,
          )}`
        : "-",
    ),
  );

  return lines.join("\n");
}
