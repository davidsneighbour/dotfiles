import { access } from "node:fs/promises";
import { delimiter, join } from "node:path";
import { commandFailureMessage, runCommand } from "../commands/run-command.ts";
import type { UsageProviderResult } from "../types.ts";
import { type ProviderDoctorResult, type UsageProvider } from "./provider.ts";

type CommandRunner = typeof runCommand;
type CommandExists = (command: string) => Promise<boolean>;

export class CodexProvider implements UsageProvider {
  id = "codex";
  displayName = "Codex";
  private readonly run: CommandRunner;
  private readonly exists: CommandExists;

  constructor(
    run: CommandRunner = runCommand,
    exists: CommandExists = commandExists,
  ) {
    this.run = run;
    this.exists = exists;
  }

  async collect(): Promise<UsageProviderResult> {
    const collectedAt = new Date().toISOString();
    const executableAvailable = await this.exists("codex");

    if (!executableAvailable) {
      return {
        provider: this.id,
        displayName: this.displayName,
        authenticated: false,
        collectedAt,
        limits: [],
        error: "codex executable not found",
      };
    }

    const doctor = await getDoctorState(this.run);

    if (!doctor.authenticated) {
      return {
        provider: this.id,
        displayName: this.displayName,
        authenticated: false,
        collectedAt,
        limits: [],
        error: doctor.error ?? "Codex authentication could not be verified",
      };
    }

    return {
      provider: this.id,
      displayName: this.displayName,
      authenticated: true,
      collectedAt,
      limits: [],
      error: CODEX_UNSUPPORTED_USAGE_MESSAGE,
    };
  }

  async doctor(): Promise<ProviderDoctorResult> {
    const version = await this.run("codex", ["--version"], {
      timeoutMs: 5_000,
    });
    const doctor = await getDoctorState(this.run);

    return {
      provider: this.id,
      displayName: this.displayName,
      checks: [
        {
          label: "executable",
          ok: version.ok,
          detail: version.ok
            ? version.stdout.trim()
            : commandFailureMessage(version),
        },
        {
          label: "authenticated",
          ok: doctor.authenticated,
          detail: doctor.authenticated ? undefined : doctor.error,
        },
        {
          label: "usage retrieval",
          ok: false,
          detail: CODEX_UNSUPPORTED_USAGE_MESSAGE,
        },
      ],
    };
  }
}

const CODEX_UNSUPPORTED_USAGE_MESSAGE =
  "Codex does not expose a non-interactive usage source yet";

async function commandExists(command: string): Promise<boolean> {
  const pathValue = process.env["PATH"];
  if (!pathValue) {
    return false;
  }

  for (const folder of pathValue.split(delimiter)) {
    try {
      await access(join(folder, command));
      return true;
    } catch {
      // Keep scanning PATH.
    }
  }

  return false;
}

export interface CodexDoctorState {
  authenticated: boolean;
  error?: string;
}

interface CodexDoctorReport {
  checks?: {
    "auth.credentials"?: {
      status?: string;
      summary?: string;
    };
  };
}

export async function getDoctorState(
  run: CommandRunner = runCommand,
): Promise<CodexDoctorState> {
  const result = await run("codex", ["doctor", "--json"], {
    timeoutMs: 20_000,
  });
  const stdout = result.stdout.trim();

  if (stdout) {
    try {
      const report = JSON.parse(stdout) as CodexDoctorReport;
      const auth = report.checks?.["auth.credentials"];
      if (auth?.status === "ok") {
        return { authenticated: true };
      }

      if (auth?.summary) {
        return { authenticated: false, error: auth.summary };
      }
    } catch {
      // Fall through to command-level error handling.
    }
  }

  return {
    authenticated: false,
    error: commandFailureMessage(result),
  };
}
