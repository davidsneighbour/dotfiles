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

function parseResetAt(line: string): string | undefined {
  const match =
    /resets\s+(?<month>[A-Za-z]{3,9})\s+(?<day>\d{1,2}),\s+(?<hour>\d{1,2})(?<ampm>am|pm)(?:\s+\((?<timezone>[^)]+)\))?/i.exec(
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
  const ampm = match.groups["ampm"]?.toLowerCase();

  if (month < 0 || !Number.isInteger(day) || !Number.isInteger(rawHour)) {
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
  const parsed = new Date(
    `${year}-${paddedMonth}-${paddedDay}T${paddedHour}:00:00${offset}`,
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
          durationSeconds: asNumber(
            limit.window?.durationSeconds ??
              limit.window?.duration_seconds ??
              limit.durationSeconds ??
              limit.duration_seconds,
          ),
          startedAt: asString(
            limit.window?.startedAt ??
              limit.window?.started_at ??
              limit.startedAt ??
              limit.started_at,
          ),
          resetsAt: asString(
            limit.window?.resetsAt ??
              limit.window?.resets_at ??
              limit.resetsAt ??
              limit.resets_at ??
              limit.reset_at,
          ),
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

  return {
    id,
    label,
    usedPercent: isRemaining ? undefined : percent,
    remainingPercent: isRemaining ? percent : undefined,
    window: {
      type: inferWindowType(label),
      resetsAt: parseResetAt(line),
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

export function parseProviderOutput(output: string): UsageLimit[] {
  const trimmed = output.trim();
  if (!trimmed) {
    return [];
  }

  try {
    const parsed = JSON.parse(trimmed) as JsonProviderOutput;
    const jsonLimits = parseJsonLimits(parsed);
    if (jsonLimits.length > 0) {
      return jsonLimits;
    }

    if (typeof parsed.result === "string") {
      return parseTextLimits(parsed.result);
    }
  } catch {
    // Human-readable provider output is handled below.
  }

  return parseTextLimits(trimmed);
}
