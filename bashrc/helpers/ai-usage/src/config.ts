import { access, constants, readFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { parse as parseToml } from "smol-toml";
import type { HealthThresholds } from "./types.ts";

export interface ProviderConfig {
  enabled: boolean;
}

export interface AiUsageConfig {
  providers: {
    claude: ProviderConfig;
    codex: ProviderConfig;
  };
  health: HealthThresholds;
}

export const DEFAULT_CONFIG_PATH = path.join(
  os.homedir(),
  ".config",
  "ai-usage",
  "config.toml",
);

const DEFAULT_CONFIG: AiUsageConfig = {
  providers: {
    claude: { enabled: true },
    codex: { enabled: true },
  },
  health: {
    warningRatio: 1.15,
    criticalRatio: 1.35,
    criticalRemainingPercent: 10,
    minimumElapsedPercent: 10,
  },
};

interface RawProviderConfig {
  enabled?: unknown;
}

interface RawConfig {
  providers?: {
    claude?: RawProviderConfig;
    codex?: RawProviderConfig;
  };
  health?: {
    warning_ratio?: unknown;
    critical_ratio?: unknown;
    critical_remaining_percent?: unknown;
    minimum_elapsed_percent?: unknown;
  };
}

async function fileExists(filePath: string): Promise<boolean> {
  try {
    await access(filePath, constants.R_OK);
    return true;
  } catch {
    return false;
  }
}

function optionalBoolean(value: unknown, fallback: boolean): boolean {
  if (value === undefined) {
    return fallback;
  }

  if (typeof value !== "boolean") {
    throw new Error(`Expected boolean config value, received ${typeof value}`);
  }

  return value;
}

function optionalNumber(value: unknown, fallback: number, key: string): number {
  if (value === undefined) {
    return fallback;
  }

  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new Error(`Expected numeric config value for ${key}`);
  }

  return value;
}

export async function loadConfig(
  configPath = DEFAULT_CONFIG_PATH,
): Promise<AiUsageConfig> {
  if (!(await fileExists(configPath))) {
    return DEFAULT_CONFIG;
  }

  const parsed = parseToml(await readFile(configPath, "utf8")) as RawConfig;

  return {
    providers: {
      claude: {
        enabled: optionalBoolean(
          parsed.providers?.claude?.enabled,
          DEFAULT_CONFIG.providers.claude.enabled,
        ),
      },
      codex: {
        enabled: optionalBoolean(
          parsed.providers?.codex?.enabled,
          DEFAULT_CONFIG.providers.codex.enabled,
        ),
      },
    },
    health: {
      warningRatio: optionalNumber(
        parsed.health?.warning_ratio,
        DEFAULT_CONFIG.health.warningRatio,
        "health.warning_ratio",
      ),
      criticalRatio: optionalNumber(
        parsed.health?.critical_ratio,
        DEFAULT_CONFIG.health.criticalRatio,
        "health.critical_ratio",
      ),
      criticalRemainingPercent: optionalNumber(
        parsed.health?.critical_remaining_percent,
        DEFAULT_CONFIG.health.criticalRemainingPercent,
        "health.critical_remaining_percent",
      ),
      minimumElapsedPercent: optionalNumber(
        parsed.health?.minimum_elapsed_percent,
        DEFAULT_CONFIG.health.minimumElapsedPercent,
        "health.minimum_elapsed_percent",
      ),
    },
  };
}
