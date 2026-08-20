import type {
  HealthThresholds,
  LimitHealth,
  UsageLimit,
  UsageLimitSummary,
  UsageLimitWithHealth,
  UsageProviderResult,
  UsageProviderResultWithHealth,
  UsageSummary,
} from "../types.ts";

function percentToRatio(value: number): number {
  return value / 100;
}

function deriveRemaining(limit: UsageLimit): number | undefined {
  if (limit.remainingPercent !== undefined) {
    return limit.remainingPercent;
  }

  if (limit.usedPercent !== undefined) {
    return Math.max(0, 100 - limit.usedPercent);
  }

  return undefined;
}

function absoluteHealth(
  remaining: number | undefined,
  thresholds: HealthThresholds,
): LimitHealth {
  if (remaining === undefined) {
    return {
      status: "unknown",
      basis: "unavailable",
      reason: "remaining quota is unavailable",
    };
  }

  if (remaining <= thresholds.criticalRemainingPercent || remaining < 15) {
    return {
      status: "critical",
      basis: "absolute",
      reason: "remaining quota is low",
    };
  }

  if (remaining < 40) {
    return {
      status: "elevated",
      basis: "absolute",
      reason: "remaining quota is reduced",
    };
  }

  return {
    status: "healthy",
    basis: "absolute",
    reason: "remaining quota is comfortable",
  };
}

export function classifyLimitHealth(
  limit: UsageLimit,
  thresholds: HealthThresholds,
  now = new Date(),
): LimitHealth {
  const remaining = deriveRemaining(limit);

  if (
    remaining !== undefined &&
    remaining <= thresholds.criticalRemainingPercent
  ) {
    return {
      status: "critical",
      basis: "absolute",
      reason: "remaining quota is critically low",
    };
  }

  if (
    limit.usedPercent === undefined ||
    !limit.window?.startedAt ||
    !limit.window.resetsAt
  ) {
    return absoluteHealth(remaining, thresholds);
  }

  const start = new Date(limit.window.startedAt);
  const reset = new Date(limit.window.resetsAt);

  if (Number.isNaN(start.getTime()) || Number.isNaN(reset.getTime())) {
    return absoluteHealth(remaining, thresholds);
  }

  const totalMs = reset.getTime() - start.getTime();
  const elapsedMs = now.getTime() - start.getTime();

  if (totalMs <= 0 || elapsedMs < 0 || reset.getTime() <= now.getTime()) {
    return absoluteHealth(remaining, thresholds);
  }

  const elapsedRatio = Math.min(1, elapsedMs / totalMs);
  const usageRatio = percentToRatio(limit.usedPercent);

  if (elapsedRatio * 100 < thresholds.minimumElapsedPercent) {
    return absoluteHealth(remaining, thresholds);
  }

  const pressureRatio = usageRatio / elapsedRatio;

  if (pressureRatio >= thresholds.criticalRatio) {
    return {
      status: "critical",
      basis: "pace",
      pressureRatio,
      elapsedRatio,
      usageRatio,
      reason: "usage is significantly ahead of elapsed time",
    };
  }

  if (pressureRatio >= thresholds.warningRatio) {
    return {
      status: "elevated",
      basis: "pace",
      pressureRatio,
      elapsedRatio,
      usageRatio,
      reason: "usage is ahead of elapsed time",
    };
  }

  return {
    status: "healthy",
    basis: "pace",
    pressureRatio,
    elapsedRatio,
    usageRatio,
    reason: "usage is on pace with elapsed time",
  };
}

export function attachHealth(
  providers: UsageProviderResult[],
  thresholds: HealthThresholds,
  now = new Date(),
): UsageProviderResultWithHealth[] {
  return providers.map((provider) => ({
    ...provider,
    limits: provider.limits.map((limit) => ({
      ...limit,
      remainingPercent: deriveRemaining(limit),
      health: classifyLimitHealth(limit, thresholds, now),
    })),
  }));
}

function toSummary(
  provider: UsageProviderResultWithHealth,
  limit: UsageLimitWithHealth,
): UsageLimitSummary {
  return {
    provider: provider.provider,
    displayName: provider.displayName,
    limitId: limit.id,
    label: limit.label,
    remainingPercent: limit.remainingPercent,
    usedPercent: limit.usedPercent,
    pressureRatio: limit.health.pressureRatio,
    resetsAt: limit.window?.resetsAt,
  };
}

export function buildSummary(
  providers: UsageProviderResultWithHealth[],
  configuredProviders: number,
  now = new Date(),
): UsageSummary {
  const availableProviders = providers.filter(
    (provider) => provider.authenticated && provider.limits.length > 0,
  ).length;
  const limits = providers.flatMap((provider) =>
    provider.limits.map((limit) => toSummary(provider, limit)),
  );
  const criticalLimits = providers.flatMap((provider) =>
    provider.limits
      .filter((limit) => limit.health.status === "critical")
      .map((limit) => toSummary(provider, limit)),
  );
  const withRemaining = limits.filter(
    (limit) => limit.remainingPercent !== undefined,
  );
  const withPressure = limits.filter(
    (limit) => limit.pressureRatio !== undefined,
  );
  const withFutureReset = limits.filter((limit) => {
    if (!limit.resetsAt) {
      return false;
    }

    return new Date(limit.resetsAt).getTime() > now.getTime();
  });

  return {
    configuredProviders,
    availableProviders,
    criticalLimits,
    highestPressure: [...withPressure].sort(
      (left: UsageLimitSummary, right: UsageLimitSummary) =>
        (right.pressureRatio ?? 0) - (left.pressureRatio ?? 0),
    )[0],
    lowestRemaining: [...withRemaining].sort(
      (left: UsageLimitSummary, right: UsageLimitSummary) =>
        (left.remainingPercent ?? 100) - (right.remainingPercent ?? 100),
    )[0],
    nextReset: [...withFutureReset].sort(
      (left: UsageLimitSummary, right: UsageLimitSummary) =>
        new Date(left.resetsAt ?? 0).getTime() -
        new Date(right.resetsAt ?? 0).getTime(),
    )[0],
  };
}
