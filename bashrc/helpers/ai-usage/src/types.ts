export type WindowType = "rolling" | "calendar" | "unknown";
export type HealthStatus = "healthy" | "elevated" | "critical" | "unknown";
export type HealthBasis = "pace" | "absolute" | "unavailable";

export interface UsageWindow {
  type: WindowType;
  durationSeconds?: number | undefined;
  startedAt?: string | undefined;
  resetsAt?: string | undefined;
}

export interface UsageLimit {
  id: string;
  label: string;
  usedPercent?: number | undefined;
  remainingPercent?: number | undefined;
  window?: UsageWindow | undefined;
}

export interface UsageProviderResult {
  provider: string;
  displayName: string;
  authenticated: boolean;
  collectedAt: string;
  limits: UsageLimit[];
  error?: string | undefined;
}

export interface HealthThresholds {
  warningRatio: number;
  criticalRatio: number;
  criticalRemainingPercent: number;
  minimumElapsedPercent: number;
}

export interface LimitHealth {
  status: HealthStatus;
  basis: HealthBasis;
  pressureRatio?: number | undefined;
  elapsedRatio?: number | undefined;
  usageRatio?: number | undefined;
  reason: string;
}

export interface UsageLimitWithHealth extends UsageLimit {
  health: LimitHealth;
}

export interface UsageProviderResultWithHealth
  extends Omit<UsageProviderResult, "limits"> {
  limits: UsageLimitWithHealth[];
}

export interface UsageSummary {
  configuredProviders: number;
  availableProviders: number;
  criticalLimits: UsageLimitSummary[];
  highestPressure?: UsageLimitSummary | undefined;
  lowestRemaining?: UsageLimitSummary | undefined;
  nextReset?: UsageLimitSummary | undefined;
}

export interface UsageLimitSummary {
  provider: string;
  displayName: string;
  limitId: string;
  label: string;
  remainingPercent?: number | undefined;
  usedPercent?: number | undefined;
  pressureRatio?: number | undefined;
  resetsAt?: string | undefined;
}

export interface UsageReport {
  collectedAt: string;
  providers: UsageProviderResultWithHealth[];
  summary: UsageSummary;
}
