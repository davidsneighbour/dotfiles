import { commandFailureMessage, runCommand } from "../commands/run-command.ts";
import type { UsageProviderResult } from "../types.ts";
import {
  type ProviderDoctorResult,
  parseProviderOutput,
  type UsageProvider,
} from "./provider.ts";

export class ClaudeCodeProvider implements UsageProvider {
  id = "claude";
  displayName = "Claude Code";

  async collect(): Promise<UsageProviderResult> {
    const collectedAt = new Date().toISOString();
    const result = await runCommand(
      "claude",
      ["-p", "/usage", "--output-format", "json", "--no-session-persistence"],
      { timeoutMs: 20_000 },
    );

    if (!result.ok) {
      return {
        provider: this.id,
        displayName: this.displayName,
        authenticated: !/auth|login/i.test(result.stderr),
        collectedAt,
        limits: [],
        error: commandFailureMessage(result),
      };
    }

    const limits = parseProviderOutput(result.stdout);
    return {
      provider: this.id,
      displayName: this.displayName,
      authenticated: true,
      collectedAt,
      limits,
      error:
        limits.length === 0
          ? "No usage limits found in Claude output"
          : undefined,
    };
  }

  async doctor(): Promise<ProviderDoctorResult> {
    const version = await runCommand("claude", ["--version"], {
      timeoutMs: 5_000,
    });
    const usage = await this.collect();

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
          ok: usage.authenticated,
          detail: usage.authenticated ? undefined : usage.error,
        },
        {
          label: "usage retrieval",
          ok: usage.limits.length > 0,
          detail: usage.limits.length > 0 ? undefined : usage.error,
        },
      ],
    };
  }
}
