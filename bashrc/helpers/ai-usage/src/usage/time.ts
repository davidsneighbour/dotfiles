export function formatDuration(seconds: number): string {
  if (!Number.isFinite(seconds)) {
    return "unknown";
  }

  const safeSeconds = Math.max(0, Math.floor(seconds));
  const days = Math.floor(safeSeconds / 86_400);
  const hours = Math.floor((safeSeconds % 86_400) / 3_600);
  const minutes = Math.floor((safeSeconds % 3_600) / 60);

  if (days > 0) {
    return `${days}d ${hours}h`;
  }

  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  }

  return `${minutes}m`;
}

export function formatResetAt(value: string | undefined, now: Date): string {
  if (!value) {
    return "-";
  }

  const reset = new Date(value);
  if (Number.isNaN(reset.getTime())) {
    return "-";
  }

  const sameDay =
    reset.getFullYear() === now.getFullYear() &&
    reset.getMonth() === now.getMonth() &&
    reset.getDate() === now.getDate();

  if (sameDay) {
    return new Intl.DateTimeFormat(undefined, {
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    }).format(reset);
  }

  return new Intl.DateTimeFormat(undefined, {
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(reset);
}

export function secondsUntil(
  value: string | undefined,
  now: Date,
): number | undefined {
  if (!value) {
    return undefined;
  }

  const target = new Date(value);
  if (Number.isNaN(target.getTime())) {
    return undefined;
  }

  return Math.max(0, (target.getTime() - now.getTime()) / 1_000);
}
