import { spawn } from "node:child_process";
import { once } from "node:events";
import { createWriteStream, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import { finished } from "node:stream/promises";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";
import { safeError } from "./collector.ts";

const help = `Daily Git collection
Usage: node tools/git-collection/src/daily.ts [flags]
  --config PATH     Discovery config (default: ~/.config/git-collection/config.json)
  --database PATH   Database (default: ~/.local/share/git-collection/catalogue.sqlite)
  --verbose         Also print the collection summary
  --help            Show this help
Logs: ~/.logs/git-collection/YYYYMMDD-HHMMSS.log (UTC)
No network requests or Git fetches are made.`;

export async function runDaily(
  options: { config?: string; database?: string; verbose?: boolean },
  userDirectory = homedir(),
): Promise<{ code: number; logPath: string }> {
  const directory = join(userDirectory, ".logs/git-collection");
  mkdirSync(directory, { recursive: true, mode: 0o700 });
  const stamp = new Date()
    .toISOString()
    .replace(/[-:]/g, "")
    .replace("T", "-")
    .slice(0, 15);
  const logPath = join(directory, `${stamp}.log`);
  const log = createWriteStream(logPath, { flags: "a", mode: 0o600 });
  const logDone = finished(log);
  // Awaited below; attach immediately to avoid an early unhandled rejection.
  void logDone.catch(() => undefined);
  try {
    await once(log, "open");
    const args = [
      fileURLToPath(new URL("./cli.ts", import.meta.url)),
      "scan",
      "--all",
    ];
    if (options.config) args.push("--config", resolve(options.config));
    if (options.database) args.push("--database", resolve(options.database));
    const child = spawn(process.execPath, args, {
      stdio: ["ignore", "pipe", "pipe"],
    });
    log.on("error", () => child.kill("SIGTERM"));
    child.stdout.on("data", (chunk: Buffer) => {
      log.write(chunk);
      if (options.verbose) process.stdout.write(chunk);
    });
    child.stderr.on("data", (chunk: Buffer) => log.write(chunk));
    const code = await new Promise<number>((resolveExit, reject) => {
      child.once("error", reject);
      child.once("close", (exitCode) => resolveExit(exitCode ?? 1));
    });
    return { code, logPath };
  } finally {
    log.end();
    await logDone;
  }
}

if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    const { values } = parseArgs({
      options: {
        config: { type: "string" },
        database: { type: "string" },
        verbose: { type: "boolean" },
        help: { type: "boolean" },
      },
    });
    if (values.help) console.log(help);
    else {
      const result = await runDaily(values);
      if (result.code !== 0) {
        console.error(
          `Daily Git collection failed. Review ${result.logPath}, fix the reported cause, and rerun this command.`,
        );
        process.exitCode = result.code;
      } else if (values.verbose) console.log(`Log: ${result.logPath}`);
    }
  } catch (error) {
    console.error(`Daily Git collection: ${safeError(error)}`);
    console.error(help);
    process.exitCode = 1;
  }
}
