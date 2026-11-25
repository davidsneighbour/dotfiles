import assert from "node:assert/strict";
import { test } from "node:test";
import {
  ConfigError,
  DEFAULT_CONFIG_FILE,
  layoutBars,
  loadConfig,
  type Monitor,
  parseIniSection,
  parseMonitors,
  parseStarterConfig,
  renderPolybarConfig,
  resolvePalette,
  scaleFont,
  shellQuote,
  type Theme,
} from "../browser-starter.ts";

const palette = new Map([
  ["background", "#17191B"],
  ["foreground", "#D2D0CB"],
  ["cyan", "#8FA9B4"],
  ["red", "#FF7D6C"],
]);

const monitor: Monitor = { name: "DP-1", width: 1920, height: 1080 };

const theme: Theme = {
  background: "#17191B",
  foreground: "#D2D0CB",
  border: "#2E3236",
  fonts: {
    text: "Text:pixelsize=14;0",
    lucide: "lucide:pixelsize=48;8",
    nerd: "Nerd:pixelsize=48;8",
    brands: "Brands:pixelsize=48;8",
  },
};

function profile(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    label: "Main",
    directory: "Default",
    icon: "\uE19F",
    colour: "cyan",
    ...overrides,
  };
}

test("the committed configuration is valid", () => {
  const config = loadConfig(DEFAULT_CONFIG_FILE);
  assert.ok(config.profiles.length > 0);
});

test("a minimal configuration gets defaults and resolved colours", () => {
  const config = parseStarterConfig({ profiles: [profile()] }, palette);
  assert.equal(config.bar.timeoutSeconds, 30);
  assert.equal(config.bar.iconPixels, 48);
  assert.equal(config.profiles[0]?.colour, "#8FA9B4");
  assert.equal(config.profiles[0]?.font, "lucide");
  assert.equal(config.close.colour, "#FF7D6C");
  assert.equal(config.close.icon, "\uE1B2");
});

test("invalid configurations are rejected with a clear error", () => {
  const cases: [unknown, RegExp][] = [
    [{ profiles: [] }, /at least one/],
    [{ profiles: [profile({ lable: "x" })] }, /unknown key "lable"/],
    [{ bar: { timeout: 5 }, profiles: [profile()] }, /unknown key "timeout"/],
    [{ profiles: [profile({ label: "Toolong" })] }, /1 to 6 characters/],
    [{ profiles: [profile({ label: "50%" })] }, /must not contain/],
    [
      { profiles: [profile({ directory: "../x" })] },
      /Chrome profile folder name/,
    ],
    [{ profiles: [profile(), profile({ label: "Two" })] }, /used twice/],
    [{ profiles: [profile({ colour: "teal" })] }, /palette name/],
    [{ profiles: [profile({ font: "emoji" })] }, /font must be one of/],
    [{ profiles: [profile({ icon: "abc" })] }, /one icon character/],
    [
      { bar: { icon_pixels: 100 }, profiles: [profile()] },
      /must not be larger/,
    ],
    [{ bar: { show_labels: "yes" }, profiles: [profile()] }, /true or false/],
  ];
  for (const [document, message] of cases) {
    assert.throws(
      () => parseStarterConfig(document, palette),
      (error: unknown) => {
        assert.ok(error instanceof ConfigError);
        assert.match(error.message, message);
        return true;
      },
    );
  }
});

test("Polybar ini sections and palette references are read", () => {
  const ini =
    '[colours]\n; comment\nred = #FF7D6C\nprimary = ${colours.red}\nname = "quoted"\n[other]\nred = #000000\n';
  const raw = parseIniSection(ini, "colours");
  assert.equal(raw.get("name"), "quoted");
  const resolved = resolvePalette(raw);
  assert.equal(resolved.get("primary"), "#FF7D6C");
  assert.equal(resolved.has("name"), false);
});

test("font patterns get a pixel size and offset", () => {
  assert.equal(
    scaleFont("lucide:style=Regular:size=10;2", 48, 8),
    "lucide:style=Regular:pixelsize=48;8",
  );
});

test("the primary monitor is preferred", () => {
  const output = "HDMI-1: 1280x1024+1920+0\nDP-1: 1920x1080+0+0 (primary)\n";
  assert.deepEqual(parseMonitors(output), {
    name: "DP-1",
    width: 1920,
    height: 1080,
  });
  assert.equal(parseMonitors("HDMI-1: 1280x1024+0+0\n")?.name, "HDMI-1");
  assert.equal(parseMonitors("no monitors"), null);
});

test("each profile is an icon bar and a label bar, the close bar is at the bottom", () => {
  const config = parseStarterConfig(
    { profiles: [profile(), profile({ directory: "Profile 1" })] },
    palette,
  );
  const bars = layoutBars(config, monitor);
  assert.deepEqual(
    bars.map((bar) => [bar.kind, bar.offsetY, bar.height]),
    [
      ["icon", 30, 76],
      ["label", 106, 20],
      ["icon", 126, 76],
      ["label", 202, 20],
      ["filler", 222, 782],
      ["close", 1004, 76],
    ],
  );
});

test("too many profiles for the monitor height are rejected", () => {
  const profiles = Array.from({ length: 20 }, (_, index) =>
    profile({ directory: `Profile ${String(index)}` }),
  );
  const config = parseStarterConfig({ profiles }, palette);
  assert.throws(() => layoutBars(config, monitor), /do not fit/);
});

test("the generated Polybar config has an icon and a label bar with click commands", () => {
  const config = parseStarterConfig(
    { profiles: [profile({ directory: "Profile 1" })] },
    palette,
  );
  const ini = renderPolybarConfig(
    config,
    monitor,
    theme,
    "'node' 'starter.ts'",
  );
  assert.match(ini, /^override-redirect = true$/m);
  assert.doesNotMatch(ini, /^modules-left/m);
  assert.match(ini, /^\[bar\/browser-starter-p0\]$/m);
  assert.match(ini, /^\[bar\/browser-starter-p0-label\]$/m);
  assert.match(ini, /^label = "%\{T2\}%\{F#8FA9B4\}\uE19F%\{F-\}%\{T-\}"$/m);
  assert.match(ini, /^label = "%\{T1\}Main%\{T-\}"$/m);
  assert.equal(
    ini.match(/^click-left = 'node' 'starter.ts' --launch 'Profile 1'$/gm)
      ?.length,
    2,
  );
  assert.match(ini, /^click-left = 'node' 'starter.ts' --close$/m);
});

test("without labels there are no label bars", () => {
  const config = parseStarterConfig(
    { bar: { show_labels: false }, profiles: [profile()] },
    palette,
  );
  assert.deepEqual(
    layoutBars(config, monitor).map((bar) => bar.kind),
    ["icon", "filler", "close"],
  );
});

test("shell quoting survives single quotes", () => {
  assert.equal(shellQuote("it's"), `'it'\\''s'`);
});
