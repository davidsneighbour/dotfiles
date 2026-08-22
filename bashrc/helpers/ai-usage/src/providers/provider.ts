import type { UsageLimit, UsageProviderResult } from "../types.ts";

export interface DoctorCheck {
  label: string;
  ok: boolean;
  detail?: string | undefined;
}

export interface ProviderDoctorResult {
  provider: string;
  displayName: string;
  checks: DoctorCheck[];
}

export interface UsageProvider {
  id: string;
  displayName: string;
  collect(): Promise<UsageProviderResult>;
  doctor(): Promise<ProviderDoctorResult>;
}

interface JsonLimit {
  id?: unknown;
  label?: unknown;
  name?: unknown;
  usedPercent?: unknown;
  used_percent?: unknown;
  remainingPercent?: unknown;
  remaining_percent?: unknown;
  resetsAt?: unknown;
  resets_at?: unknown;
  reset_at?: unknown;
  startedAt?: unknown;
  started_at?: unknown;
  durationSeconds?: unknown;
  duration_seconds?: unknown;
  window?: {
    type?: unknown;
    durationSeconds?: unknown;
    duration_seconds?: unknown;
    startedAt?: unknown;
    started_at?: unknown;
    resetsAt?: unknown;
    resets_at?: unknown;
  };
}

interface JsonProviderOutput {
  result?: unknown;
}

function asString(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

function asNumber(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value)
    ? value
    : undefined;
}

function inferWindowType(label: string): "rolling" | "calendar" | "unknown" {
  const normalised = label.toLowerCase();
  if (normalised.includes("hour") || normalised.includes("session")) {
    return "rolling";
  }

  if (
    normalised.includes("week") ||
    normalised.includes("month") ||
    normalised.includes("day")
  ) {
    return "calendar";
  }

  return "unknown";
}

const HOUR_SECONDS = 60 * 60;
const DAY_SECONDS = 24 * HOUR_SECONDS;

// Providers report only a reset time, not a window start. These durations are
// the publicly documented Claude quota windows and let health scoring derive
// startedAt (window start = resetsAt - duration) instead of falling back to
// absolute-only classification for every Claude limit.
const KNOWN_WINDOW_DURATIONS_SECONDS: Record<string, number> = {
  session: 5 * HOUR_SECONDS,
  "5-hour": 5 * HOUR_SECONDS,
  weekly: 7 * DAY_SECONDS,
};

function knownWindowDurationSeconds(label: string): number | undefined {
  return KNOWN_WINDOW_DURATIONS_SECONDS[label.toLowerCase()];
}

function deriveStartedAt(
  resetsAt: string | undefined,
  durationSeconds: number | undefined,
): string | undefined {
  if (!resetsAt || durationSeconds === undefined) {
    return undefined;
  }

  const reset = new Date(resetsAt);
  if (Number.isNaN(reset.getTime())) {
    return undefined;
  }

  return new Date(reset.getTime() - durationSeconds * 1_000).toISOString();
}

function parseResetAt(line: string): string | undefined {
  // Claude reports reset times both as a whole hour ("resets Aug 20, 4pm")
  // and, depending on how close the reset is, with minutes ("resets Aug 22,
  // 7:59pm") — the minute group must stay optional to match both.
  const match =
    /resets\s+(?<month>[A-Za-z]{3,9})\s+(?<day>\d{1,2}),\s+(?<hour>\d{1,2})(?::(?<minute>\d{2}))?(?<ampm>am|pm)(?:\s+\((?<timezone>[^)]+)\))?/i.exec(
      line,
    );
  if (!match?.groups) {
    return undefined;
  }

  const monthNames = [
    "jan",
    "feb",
    "mar",
    "apr",
    "may",
    "jun",
    "jul",
    "aug",
    "sep",
    "oct",
    "nov",
    "dec",
  ];
  const month = monthNames.indexOf(
    match.groups["month"]?.slice(0, 3).toLowerCase() ?? "",
  );
  const day = Number.parseInt(match.groups["day"] ?? "", 10);
  const rawHour = Number.parseInt(match.groups["hour"] ?? "", 10);
  const minute = Number.parseInt(match.groups["minute"] ?? "0", 10);
  const ampm = match.groups["ampm"]?.toLowerCase();

  if (
    month < 0 ||
    !Number.isInteger(day) ||
    !Number.isInteger(rawHour) ||
    !Number.isInteger(minute)
  ) {
    return undefined;
  }

  const hour =
    ampm === "pm" && rawHour < 12
      ? rawHour + 12
      : ampm === "am" && rawHour === 12
        ? 0
        : rawHour;
  const year = new Date().getFullYear();
  const timezone = match.groups["timezone"];
  const offset = timezone === "Asia/Bangkok" ? "+07:00" : "";
  const paddedMonth = String(month + 1).padStart(2, "0");
  const paddedDay = String(day).padStart(2, "0");
  const paddedHour = String(hour).padStart(2, "0");
  const paddedMinute = String(minute).padStart(2, "0");
  const parsed = new Date(
    `${year}-${paddedMonth}-${paddedDay}T${paddedHour}:${paddedMinute}:00${offset}`,
  );

  if (Number.isNaN(parsed.getTime())) {
    return undefined;
  }

  return parsed.toISOString();
}

function parseJsonLimits(value: unknown): UsageLimit[] {
  const root = value as {
    limits?: unknown;
    usage?: { limits?: unknown };
    data?: { limits?: unknown };
  };
  const candidates = root.limits ?? root.usage?.limits ?? root.data?.limits;

  if (!Array.isArray(candidates)) {
    return [];
  }

  return candidates.flatMap((rawLimit, index) => {
    const limit = rawLimit as JsonLimit;
    const label =
      asString(limit.label) ?? asString(limit.name) ?? `limit ${index + 1}`;
    const id =
      asString(limit.id) ?? label.toLowerCase().replace(/[^a-z0-9]+/g, "-");
    const usedPercent = asNumber(limit.usedPercent ?? limit.used_percent);
    const remainingPercent = asNumber(
      limit.remainingPercent ?? limit.remaining_percent,
    );

    if (usedPercent === undefined && remainingPercent === undefined) {
      return [];
    }

    const resetsAt = asString(
      limit.window?.resetsAt ??
        limit.window?.resets_at ??
        limit.resetsAt ??
        limit.resets_at ??
        limit.reset_at,
    );
    const durationSeconds =
      asNumber(
        limit.window?.durationSeconds ??
          limit.window?.duration_seconds ??
          limit.durationSeconds ??
          limit.duration_seconds,
      ) ?? knownWindowDurationSeconds(label);
    const startedAt =
      asString(
        limit.window?.startedAt ??
          limit.window?.started_at ??
          limit.startedAt ??
          limit.started_at,
      ) ?? deriveStartedAt(resetsAt, durationSeconds);

    return [
      {
        id,
        label,
        usedPercent,
        remainingPercent,
        window: {
          type:
            limit.window?.type === "rolling" ||
            limit.window?.type === "calendar"
              ? limit.window.type
              : inferWindowType(label),
          durationSeconds,
          startedAt,
          resetsAt,
        },
      },
    ];
  });
}

function parsePercentLine(line: string, index = 0): UsageLimit | undefined {
  const percentMatches = [
    ...line.matchAll(/(?<percent>\d{1,3}(?:\.\d+)?)\s*%/g),
  ];
  const percentMatch = percentMatches[index];
  const rawPercent = percentMatch?.groups?.["percent"];
  if (!rawPercent || percentMatch.index === undefined) {
    return undefined;
  }

  const percent = Number.parseFloat(rawPercent);
  if (!Number.isFinite(percent)) {
    return undefined;
  }

  const lower = line.toLowerCase();
  const isRemaining = lower.includes("remain") || lower.includes("left");
  const labelText = line.slice(0, percentMatch.index).toLowerCase();
  let label = "limit";

  if (labelText.includes("week") || lower.includes("weekly")) {
    label = "weekly";
  } else if (labelText.includes("session")) {
    label = "session";
  } else if (labelText.includes("5-hour") || labelText.includes("5 hour")) {
    label = "5-hour";
  } else {
    const labelMatch =
      /(?<label>5[- ]?hour|weekly|daily|monthly|session|limit)/i.exec(line);
    label = labelMatch?.groups?.["label"] ?? "limit";
  }

  const id = label.toLowerCase().replace(/[^a-z0-9]+/g, "-");
  const resetsAt = parseResetAt(line);
  const durationSeconds = knownWindowDurationSeconds(label);
  const startedAt = deriveStartedAt(resetsAt, durationSeconds);

  return {
    id,
    label,
    usedPercent: isRemaining ? undefined : percent,
    remainingPercent: isRemaining ? percent : undefined,
    window: {
      type: inferWindowType(label),
      durationSeconds,
      startedAt,
      resetsAt,
    },
  };
}

function parseTextLimits(value: string): UsageLimit[] {
  return value.split("\n").flatMap((line) => {
    const lower = line.toLowerCase();
    const looksLikeQuotaLine =
      lower.includes("limit") ||
      lower.startsWith("current session") ||
      lower.startsWith("current week");

    if (!looksLikeQuotaLine) {
      return [];
    }

    const percentCount = [...line.matchAll(/\d{1,3}(?:\.\d+)?\s*%/g)].length;
    return Array.from({ length: percentCount }, (_unused, index) =>
      parsePercentLine(line, index),
    ).filter((limit): limit is UsageLimit => limit !== undefined);
  });
}

// `claude --output-format json` occasionally leaks unrelated diagnostic
// lines (e.g. MCP client logging) onto stdout after the JSON payload, which
// breaks a plain JSON.parse(trimmed) on the whole blob. The JSON object is
// always the first line, so retry against just that line before giving up
// and falling back to whole-blob text parsing.
function parseJsonEnvelope(trimmed: string): JsonProviderOutput | undefined {
  try {
    return JSON.parse(trimmed) as JsonProviderOutput;
  } catch {
    // Fall through to a first-line retry below.
  }

  const firstLine = trimmed.split("\n", 1)[0]?.trim();
  if (!firstLine || firstLine === trimmed) {
    return undefined;
  }

  try {
    return JSON.parse(firstLine) as JsonProviderOutput;
  } catch {
    return undefined;
  }
}

export function parseProviderOutput(output: string): UsageLimit[] {
  const trimmed = output.trim();
  if (!trimmed) {
    return [];
  }

  const parsed = parseJsonEnvelope(trimmed);
  if (parsed) {
    const jsonLimits = parseJsonLimits(parsed);
    if (jsonLimits.length > 0) {
      return jsonLimits;
    }

    if (typeof parsed.result === "string") {
      return parseTextLimits(parsed.result);
    }
  }

  return parseTextLimits(trimmed);
}
