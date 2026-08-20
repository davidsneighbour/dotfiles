import { access } from "node:fs/promises";
import { delimiter, join } from "node:path";
import { commandFailureMessage, runCommand } from "../commands/run-command.ts";
import type { UsageProviderResult } from "../types.ts";
import { type ProviderDoctorResult, type UsageProvider } from "./provider.ts";

export class CodexProvider implements UsageProvider {
  id = "codex";
  displayName = "Codex";

  async collect(): Promise<UsageProviderResult> {
    const collectedAt = new Date().toISOString();
    const executableAvailable = await commandExists("codex");

    return {
      provider: this.id,
      displayName: this.displayName,
      authenticated: executableAvailable,
      collectedAt,
      limits: [],
      error: executableAvailable
        ? "Codex does not expose a non-interactive usage source yet"
        : "codex executable not found",
    };
  }

  async doctor(): Promise<ProviderDoctorResult> {
    const version = await runCommand("codex", ["--version"], {
      timeoutMs: 5_000,
    });
    const doctor = await getDoctorState();

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
          detail: "Codex does not expose a non-interactive usage source yet",
        },
      ],
    };
  }
}

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

interface CodexDoctorState {
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

async function getDoctorState(): Promise<CodexDoctorState> {
  const result = await runCommand("codex", ["doctor", "--json"], {
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
