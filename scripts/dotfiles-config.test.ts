import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const cli = fileURLToPath(new URL("./dotfiles-config.ts", import.meta.url));
test("configuration CLI validates and preserves files on failure", () => {
  const directory = mkdtempSync(join(tmpdir(), "dotfiles-config-"));
  const config = join(directory, "config.json");
  const initial = '{"schemaVersion":1,"dotfiles":{}}\n';
  const run = (...args: string[]) =>
    spawnSync(process.execPath, [cli, "--config", config, ...args], {
      encoding: "utf8",
      cwd: directory,
    });
  try {
    writeFileSync(config, initial);
    assert.equal(run("--action", "validate").status, 0);
    assert.equal(
      run("--action", "get", "--pointer", "/schemaVersion").stdout,
      "1\n",
    );
    for (const args of [
      [],
      ["--unknown"],
      ["--action", "set"],
      ["--action", "get", "--pointer", "/missing"],
      ["--action", "get", "--pointer", "/bad~2"],
      ["--action", "set", "--pointer", "/__proto__", "--value", "{}"],
      ["--action", "set", "--pointer", "/schemaVersion", "--value", "2"],
      ["--action", "set", "--pointer", "/dotfiles/unknown", "--value", "true"],
      ["--action", "set", "--pointer", "/dotfiles", "--value", "invalid"],
      ["--action", "validate", "--raw"],
      ["--action", "get", "--raw", "--pointer", "/schemaVersion"],
      ...[
        '{"session":{"unknown":"x"}}',
        '{"session":{"wallpaperImage":""}}',
        '{"session":{"lockScreenImage":"~/lock.jpg"}}',
        '{"session":{"wallpaperImage":1}}',
      ].map((value) => [
        "--action",
        "set",
        "--pointer",
        "/dotfiles",
        "--value",
        value,
      ]),
    ]) {
      const result = run(...args);
      assert.equal(result.status, 1, JSON.stringify(args));
      assert.match(result.stderr, /dotfiles-config:/u);
      assert.equal(result.stdout, "");
      assert.equal(readFileSync(config, "utf8"), initial);
    }
    assert.equal(
      run("--action", "set", "--pointer", "/dotfiles", "--value", "{}").status,
      0,
    );
    assert.deepEqual(
      JSON.parse(readFileSync(config, "utf8")),
      JSON.parse(initial),
    );
    const session = {
      wallpaperImage: "configs/session/i3/wallpaper.jpg",
      lockScreenImage: "/usr/share/backgrounds/lock screen.png",
    };
    assert.equal(
      run(
        "--action",
        "set",
        "--pointer",
        "/dotfiles",
        "--value",
        JSON.stringify({ session }),
      ).status,
      0,
    );
    for (const [key, expected] of Object.entries(session))
      assert.equal(
        run("--action", "get", "--raw", "--pointer", `/dotfiles/session/${key}`)
          .stdout,
        `${expected}\n`,
      );
    assert.equal(
      run("--action", "get", "--raw", "--pointer", "/dotfiles/session").status,
      1,
    );
    assert.equal(run("--help").status, 0);
    writeFileSync(config, "{");
    assert.equal(run("--action", "validate").status, 1);
    rmSync(config);
    assert.equal(run("--action", "validate").status, 1);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test("custom schema, environment paths, escaped pointers, and Bash wrapper", () => {
  const directory = mkdtempSync(join(tmpdir(), "dotfiles-paths-"));
  const config = join(directory, "custom.json");
  const schema = join(directory, "schema.json");
  const run = (...args: string[]) =>
    spawnSync(process.execPath, [cli, ...args], {
      cwd: directory,
      encoding: "utf8",
      env: { ...process.env, DOTFILES_CONFIG: config, DOTFILES_SCHEMA: schema },
    });
  try {
    writeFileSync(
      schema,
      JSON.stringify({
        type: "object",
        additionalProperties: { type: "string" },
      }),
    );
    writeFileSync(config, JSON.stringify({ "a/b~c": "old" }));
    assert.equal(
      run("--action", "set", "--pointer", "/a~1b~0c", "--value", '"new"')
        .status,
      0,
    );
    assert.equal(
      run("--action", "get", "--pointer", "/a~1b~0c").stdout,
      '"new"\n',
    );
    assert.equal(
      run("--action", "set", "--pointer", "", "--value", "{}").status,
      0,
    );
    assert.equal(
      run("--action", "validate", "--schema", "missing.json").status,
      1,
    );
    assert.equal(
      run("--action", "validate", "--config", "missing.json").status,
      1,
    );
    const wrapper = fileURLToPath(
      new URL("./dotfiles-config.sh", import.meta.url),
    );
    const result = spawnSync(
      "bash",
      [wrapper, "--action", "validate", "--config", config, "--schema", schema],
      {
        cwd: directory,
        encoding: "utf8",
        env: { ...process.env, CDPATH: "/" },
      },
    );
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, "");
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
