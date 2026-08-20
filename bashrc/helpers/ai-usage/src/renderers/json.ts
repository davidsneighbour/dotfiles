import type { UsageReport } from "../types.ts";

export function renderJsonReport(report: UsageReport): string {
  return JSON.stringify(report, null, 2);
}
