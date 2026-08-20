import process from "node:process";
import { runDoctor } from "./commands/doctor.ts";
import { DEFAULT_CONFIG_PATH, loadConfig } from "./config.ts";
import { ClaudeCodeProvider } from "./providers/claude-code.ts";
import { CodexProvider } from "./providers/codex.ts";
import type { UsageProvider } from "./providers/provider.ts";
import { renderJsonReport } from "./renderers/json.ts";
import { renderTerminalReport } from "./renderers/terminal.ts";
import type { UsageProviderResult, UsageReport } from "./types.ts";
import { attachHealth, buildSummary } from "./usage/health.ts";

interface CliOptions {
  command: "dashboard" | "doctor";
  json: boolean;
  configPath: string;
  help: boolean;
}

function printHelp(): void {
  console.log(
    `
Usage:
  ai-usage [--json] [--config <path>]
  ai-usage doctor [--config <path>]

Options:
  --json           Print normalised JSON plus health information.
  --config <path>  TOML config path. Default: ${DEFAULT_CONFIG_PATH}
  --help           Show this help.

Default config:
  [providers.claude]
  enabled = true

  [providers.codex]
  enabled = true
`.trim(),
  );
}

function parseArgs(argv: string[]): CliOptions {
  const options: CliOptions = {
    command: "dashboard",
    json: false,
    configPath: DEFAULT_CONFIG_PATH,
    help: false,
  };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];

    switch (arg) {
      case "doctor":
        options.command = "doctor";
        break;
      case "--json":
        options.json = true;
        break;
      case "--config": {
        const value = argv[index + 1];
        if (!value) {
          throw new Error("--config requires a value");
        }
        options.configPath = value;
        index += 1;
        break;
      }
      case "--help":
      case "-h":
        options.help = true;
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return options;
}

function buildProviders(
  config: Awaited<ReturnType<typeof loadConfig>>,
): UsageProvider[] {
  const providers: UsageProvider[] = [];

  if (config.providers.claude.enabled) {
    providers.push(new ClaudeCodeProvider());
  }

  if (config.providers.codex.enabled) {
    providers.push(new CodexProvider());
  }

  return providers;
}

async function collectProviders(
  providers: UsageProvider[],
): Promise<UsageProviderResult[]> {
  return Promise.all(
    providers.map(async (provider) => {
      try {
        return await provider.collect();
      } catch (error) {
        return {
          provider: provider.id,
          displayName: provider.displayName,
          authenticated: false,
          collectedAt: new Date().toISOString(),
          limits: [],
          error:
            error instanceof Error ? error.message : "Unknown provider error",
        };
      }
    }),
  );
}

export async function main(argv = process.argv): Promise<number> {
  let options: CliOptions;
  try {
    options = parseArgs(argv);
  } catch (error) {
    console.error(error instanceof Error ? error.message : "Invalid arguments");
    printHelp();
    return 2;
  }

  if (options.help) {
    printHelp();
    return 0;
  }

  let config: Awaited<ReturnType<typeof loadConfig>>;
  try {
    config = await loadConfig(options.configPath);
  } catch (error) {
    console.error(
      `Invalid configuration: ${error instanceof Error ? error.message : "unknown error"}`,
    );
    return 2;
  }

  const providers = buildProviders(config);

  if (options.command === "doctor") {
    const result = await runDoctor(providers);
    console.log(result.output);
    return result.ok ? 0 : 1;
  }

  const collectedAt = new Date().toISOString();
  const rawProviders = await collectProviders(providers);
  const providersWithHealth = attachHealth(rawProviders, config.health);
  const report: UsageReport = {
    collectedAt,
    providers: providersWithHealth,
    summary: buildSummary(providersWithHealth, providers.length),
  };
  const allFailed = report.providers.every(
    (provider) => provider.limits.length === 0,
  );

  if (options.json) {
    console.log(renderJsonReport(report));
  } else {
    const colour =
      process.stdout.isTTY && process.env["NO_COLOR"] === undefined;
    console.log(renderTerminalReport(report, { colour }));
  }

  for (const provider of report.providers) {
    if (provider.error) {
      console.error(`${provider.displayName}: ${provider.error}`);
    }
  }

  return allFailed ? 1 : 0;
}
