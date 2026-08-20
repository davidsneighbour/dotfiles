import { spawn } from "node:child_process";

export interface CommandResult {
  ok: boolean;
  command: string;
  args: string[];
  exitCode?: number | undefined;
  signal?: NodeJS.Signals | undefined;
  stdout: string;
  stderr: string;
  errorCode?: string | undefined;
  timedOut: boolean;
}

export interface CommandOptions {
  timeoutMs: number;
  env?: NodeJS.ProcessEnv;
}

export function runCommand(
  command: string,
  args: string[],
  options: CommandOptions,
): Promise<CommandResult> {
  return new Promise((resolve) => {
    const child = spawn(command, args, {
      env: options.env,
      shell: false,
      stdio: ["ignore", "pipe", "pipe"],
    });

    const stdout: Buffer[] = [];
    const stderr: Buffer[] = [];
    let settled = false;
    let timedOut = false;

    const finish = (result: Omit<CommandResult, "command" | "args">): void => {
      if (settled) {
        return;
      }

      settled = true;
      clearTimeout(timer);
      resolve({
        command,
        args,
        ...result,
        stdout: Buffer.concat(stdout).toString("utf8"),
        stderr: Buffer.concat(stderr).toString("utf8"),
      });
    };

    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGTERM");
    }, options.timeoutMs);

    child.stdout?.on("data", (chunk: Buffer) => {
      stdout.push(chunk);
    });

    child.stderr?.on("data", (chunk: Buffer) => {
      stderr.push(chunk);
    });

    child.on("error", (error: NodeJS.ErrnoException) => {
      finish({
        ok: false,
        errorCode: error.code,
        timedOut,
        stdout: "",
        stderr: error.message,
      });
    });

    child.on("close", (exitCode, signal) => {
      finish({
        ok: exitCode === 0 && !timedOut,
        exitCode: exitCode ?? undefined,
        signal: signal ?? undefined,
        timedOut,
        stdout: "",
        stderr: "",
      });
    });
  });
}

export function commandFailureMessage(result: CommandResult): string {
  if (result.errorCode === "ENOENT") {
    return `${result.command} executable not found`;
  }

  if (result.timedOut) {
    return `${result.command} timed out`;
  }

  const detail = result.stderr.trim() || result.stdout.trim();
  if (detail) {
    return detail.split("\n")[0] ?? `${result.command} failed`;
  }

  return `${result.command} exited with status ${result.exitCode ?? "unknown"}`;
}
