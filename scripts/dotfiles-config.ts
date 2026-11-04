import { randomUUID } from "node:crypto";
import { lstat, readFile, rename, unlink, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";
import { Ajv } from "ajv";

const root = fileURLToPath(new URL("../", import.meta.url));
const help = `Usage: node scripts/dotfiles-config.ts --action validate|get|set [options]
  --config PATH   Configuration (default: DOTFILES_CONFIG or repository configs/dotfiles.json)
  --schema PATH   Schema (default: DOTFILES_SCHEMA or repository schema)
  --pointer PATH  JSON Pointer for get/set; empty string selects the document
  --value JSON    JSON value for set (strings must be JSON-quoted)
  --verbose      Print selected paths to stderr
  --help         Show help
Examples:
  bash scripts/dotfiles-config.sh --action validate
  node scripts/dotfiles-config.ts --action get --pointer /schemaVersion
  node scripts/dotfiles-config.ts --action set --pointer /dotfiles --value '{}'
Exit codes: 0 success, 1 invalid input, validation failure, or I/O failure.
`;

function tokens(pointer: string): string[] {
  if (pointer === "") return [];
  if (!pointer.startsWith("/") || /~(?![01])/u.test(pointer))
    throw new Error("Use a valid JSON Pointer, such as /dotfiles/workspaces.");
  return pointer
    .slice(1)
    .split("/")
    .map((part) => {
      const token = part.replaceAll("~1", "/").replaceAll("~0", "~");
      if (["__proto__", "prototype", "constructor"].includes(token))
        throw new Error("Unsafe pointer segment.");
      return token;
    });
}

function object(value: unknown): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value))
    throw new Error(
      "Pointer parents must be objects; array element updates are not supported.",
    );
  return value as Record<string, unknown>;
}

function lookup(value: unknown, parts: string[]): unknown {
  let current = value;
  for (const part of parts) {
    const parent = object(current);
    if (!Object.hasOwn(parent, part))
      throw new Error(`Pointer segment does not exist: ${part}`);
    current = parent[part];
  }
  return current;
}

async function main(): Promise<void> {
  if (Number(process.versions.node.split(".")[0]) < 24)
    throw new Error("Node.js 24 or newer is required.");
  const { values } = parseArgs({
    options: {
      action: { type: "string" },
      config: { type: "string" },
      schema: { type: "string" },
      pointer: { type: "string" },
      value: { type: "string" },
      verbose: { type: "boolean" },
      help: { type: "boolean" },
    },
  });
  if (values.help) {
    process.stdout.write(help);
    return;
  }
  if (!values.action || !["validate", "get", "set"].includes(values.action))
    throw new Error("Supply --action validate, get, or set.");
  if (
    values.action === "validate" &&
    (values.pointer !== undefined || values.value !== undefined)
  )
    throw new Error("validate does not accept --pointer or --value.");
  if (values.action === "get" && values.value !== undefined)
    throw new Error("get does not accept --value.");
  if (
    values.action === "set" &&
    (values.pointer === undefined || values.value === undefined)
  )
    throw new Error("set requires --pointer and --value.");
  const config = resolve(
    values.config ??
      process.env["DOTFILES_CONFIG"] ??
      join(root, "configs/dotfiles.json"),
  );
  const schema = resolve(
    values.schema ??
      process.env["DOTFILES_SCHEMA"] ??
      join(root, "schema/dotfiles.schema.json"),
  );
  if (values.verbose)
    process.stderr.write(`Configuration: ${config}\nSchema: ${schema}\n`);
  const original = await readFile(config, "utf8");
  let document: unknown = JSON.parse(original);
  const validator = new Ajv({ allErrors: true, strict: true });
  const validate = validator.compile(
    JSON.parse(await readFile(schema, "utf8")) as object,
  );
  const check = (candidate: unknown): void => {
    if (!validate(candidate))
      throw new Error(
        `Configuration validation failed: ${validator.errorsText(validate.errors, { separator: "; " })}`,
      );
  };
  check(document);
  if (values.action === "get") {
    process.stdout.write(
      `${JSON.stringify(lookup(document, tokens(values.pointer ?? "")), null, 2)}\n`,
    );
  } else if (values.action === "set") {
    const parts = tokens(values.pointer ?? "");
    const replacement: unknown = JSON.parse(values.value ?? "");
    if (parts.length === 0) document = replacement;
    else {
      const key = parts.pop();
      if (key === undefined) throw new Error("Missing pointer key.");
      object(lookup(document, parts))[key] = replacement;
    }
    check(document);
    const metadata = await lstat(config);
    if (!metadata.isFile())
      throw new Error("Updates require a regular file, not a symbolic link.");
    const temporary = join(dirname(config), `.dotfiles-${randomUUID()}.tmp`);
    // Exclusive temporary creation and same-directory rename prevent partial files.
    try {
      await writeFile(temporary, `${JSON.stringify(document, null, 2)}\n`, {
        flag: "wx",
        mode: metadata.mode & 0o777,
      });
      if ((await readFile(config, "utf8")) !== original)
        throw new Error(
          "Configuration changed during update; retry the command.",
        );
      await rename(temporary, config);
    } finally {
      await unlink(temporary).catch((error: unknown) => {
        if (
          !(
            error instanceof Error &&
            "code" in error &&
            error.code === "ENOENT"
          )
        )
          throw error;
      });
    }
  }
}

main().catch((error: unknown) => {
  process.stderr.write(
    `dotfiles-config: ${error instanceof Error ? error.message : String(error)}\n\n${help}`,
  );
  process.exitCode = 1;
});
