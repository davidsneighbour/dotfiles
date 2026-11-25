#!/usr/bin/env node
/**
 * Browser starter: a temporary Polybar side bar on the left edge of the
 * screen. Each button starts Google Chrome with one configured Chrome
 * profile. The bar closes itself after a timeout, after a click on a
 * profile, or after a click on the close button.
 *
 * Polybar draws only horizontal bars, so the side bar is a stack of small
 * override-redirect bars: one bar per profile, one filler bar, and one close
 * bar. They use the colours and fonts of the top bar
 * (configs/session/polybar/configs/01-colours.ini and 01-fonts.ini).
 *
 * See README.md in this folder and "Browser starter" in SESSION.md.
 */

import { spawn, spawnSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import {
  accessSync,
  appendFileSync,
  closeSync,
  constants as fsConstants,
  mkdirSync,
  openSync,
  readFileSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import { parse as parseToml } from "smol-toml";

const SCRIPT_PATH = fileURLToPath(import.meta.url);
const SCRIPT_DIR = path.dirname(SCRIPT_PATH);
const REPO_ROOT = path.resolve(SCRIPT_DIR, "..", "..", "..");
const POLYBAR_CONFIG_DIR = path.join(
  REPO_ROOT,
  "configs",
  "session",
  "polybar",
  "configs",
);
const COMMAND_NAME = "browser-starter";
const BAR_PREFIX = "browser-starter";
const MAX_LABEL_LENGTH = 6;
const HEX_COLOUR = /^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/;
const PROFILE_DIRECTORY = /^[A-Za-z0-9][A-Za-z0-9 _.-]*$/;
const STARTUP_CHECK_MS = 500;

export const DEFAULT_CONFIG_FILE = path.join(
  SCRIPT_DIR,
  "browser-starter.toml",
);

export type FontName = "lucide" | "nerd" | "brands";

const FONT_NAMES: readonly FontName[] = ["lucide", "nerd", "brands"];

/** Keys in the [fonts] section of the top bar's 01-fonts.ini. */
const FONT_KEYS: Record<FontName | "text", string> = {
  text: "text",
  lucide: "icons-lucide",
  nerd: "icons-nerd",
  brands: "icons-brands",
};

/** Polybar %{Tn} index (1-based) of each font in the generated config. */
const FONT_TAGS: Record<FontName | "text", number> = {
  text: 1,
  lucide: 2,
  nerd: 3,
  brands: 4,
};

export interface BarSettings {
  timeoutSeconds: number;
  iconPixels: number;
  iconOffsetPixels: number;
  labelPixels: number;
  itemHeightPixels: number;
  widthPixels: number;
  topOffsetPixels: number;
  showLabels: boolean;
}

export interface IconSpec {
  icon: string;
  font: FontName;
  /** Resolved hex colour. */
  colour: string;
}

export interface ProfileSpec extends IconSpec {
  label: string;
  directory: string;
}

export interface StarterConfig {
  bar: BarSettings;
  close: IconSpec;
  profiles: ProfileSpec[];
}

export interface Monitor {
  name: string;
  width: number;
  height: number;
}

export interface Theme {
  background: string;
  foreground: string;
  border: string;
  /** Polybar font patterns, already scaled to the configured sizes. */
  fonts: Record<FontName | "text", string>;
}

interface SessionState {
  token: string;
  configFile: string;
  polybarConfig: string;
  polybarPids: number[];
  timerPid: number | null;
  logFile: string;
  openedAt: string;
}

export class ConfigError extends Error {}
class UsageError extends Error {}

let verbose = false;
let sessionLogFile: string | null = null;

// ---------------------------------------------------------------------------
// Output and logging
// ---------------------------------------------------------------------------

function timestamp(date: Date = new Date()): string {
  const pad = (value: number): string => String(value).padStart(2, "0");
  return `${String(date.getFullYear())}${pad(date.getMonth() + 1)}${pad(date.getDate())}-${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`;
}

function logDirectory(): string {
  return path.join(os.homedir(), ".logs", "browser-starter");
}

function writeLog(level: string, message: string): void {
  if (sessionLogFile === null) {
    return;
  }
  try {
    appendFileSync(
      sessionLogFile,
      `${new Date().toISOString()} ${level} ${message}\n`,
    );
  } catch {
    // A broken log file must not stop the starter.
  }
}

function debug(message: string): void {
  writeLog("debug", message);
  if (verbose) {
    process.stderr.write(`${COMMAND_NAME}: ${message}\n`);
  }
}

function warn(message: string): void {
  writeLog("warning", message);
  process.stderr.write(`${COMMAND_NAME}: warning: ${message}\n`);
}

/** Report an error on stderr, in the session log, and as a notification. */
function reportError(message: string): void {
  writeLog("error", message);
  process.stderr.write(`${COMMAND_NAME}: error: ${message}\n`);
  if (findExecutable("notify-send") !== null) {
    spawnSync(
      "notify-send",
      [
        "--app-name=Browser starter",
        "--urgency=critical",
        "Browser starter",
        message,
      ],
      { stdio: "ignore" },
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function findExecutable(name: string): string | null {
  for (const directory of (process.env["PATH"] ?? "").split(path.delimiter)) {
    if (directory === "") {
      continue;
    }
    const candidate = path.join(directory, name);
    try {
      accessSync(candidate, fsConstants.X_OK);
      return candidate;
    } catch {
      // Not in this PATH entry.
    }
  }
  return null;
}

/** Quote a value for /bin/sh, which runs Polybar click commands. */
export function shellQuote(value: string): string {
  return `'${value.replaceAll("'", `'\\''`)}'`;
}

function isAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function commandLine(pid: number): string[] {
  try {
    return readFileSync(`/proc/${String(pid)}/cmdline`, "utf8")
      .split("\0")
      .filter((part) => part !== "");
  } catch {
    return [];
  }
}

function sleep(milliseconds: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, milliseconds);
  });
}

function stateDirectory(): string {
  const runtime = process.env["XDG_RUNTIME_DIR"];
  if (runtime !== undefined && runtime !== "") {
    return path.join(runtime, "dnb-browser-starter");
  }
  return path.join(
    os.tmpdir(),
    `dnb-browser-starter-${String(os.userInfo().uid)}`,
  );
}

function stateFile(): string {
  return path.join(stateDirectory(), "state.json");
}

function chromeUserDataDirectory(): string {
  const configHome = process.env["XDG_CONFIG_HOME"];
  const base =
    configHome !== undefined && configHome !== ""
      ? configHome
      : path.join(os.homedir(), ".config");
  return path.join(base, "google-chrome");
}

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

function expectTable(value: unknown, where: string): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new ConfigError(`${where} must be a table`);
  }
  return value as Record<string, unknown>;
}

function rejectUnknownKeys(
  table: Record<string, unknown>,
  allowed: readonly string[],
  where: string,
): void {
  for (const key of Object.keys(table)) {
    if (!allowed.includes(key)) {
      throw new ConfigError(
        `${where}: unknown key "${key}" (allowed: ${allowed.join(", ")})`,
      );
    }
  }
}

function readInteger(
  table: Record<string, unknown>,
  key: string,
  where: string,
  fallback: number,
  minimum: number,
  maximum: number,
): number {
  const value = table[key];
  if (value === undefined) {
    return fallback;
  }
  const number = typeof value === "bigint" ? Number(value) : value;
  if (typeof number !== "number" || !Number.isInteger(number)) {
    throw new ConfigError(`${where}.${key} must be an integer`);
  }
  if (number < minimum || number > maximum) {
    throw new ConfigError(
      `${where}.${key} must be between ${String(minimum)} and ${String(maximum)}`,
    );
  }
  return number;
}

function readBoolean(
  table: Record<string, unknown>,
  key: string,
  where: string,
  fallback: boolean,
): boolean {
  const value = table[key];
  if (value === undefined) {
    return fallback;
  }
  if (typeof value !== "boolean") {
    throw new ConfigError(`${where}.${key} must be true or false`);
  }
  return value;
}

function readString(
  table: Record<string, unknown>,
  key: string,
  where: string,
  fallback?: string,
): string {
  const value = table[key];
  if (value === undefined) {
    if (fallback !== undefined) {
      return fallback;
    }
    throw new ConfigError(`${where}.${key} is required`);
  }
  if (typeof value !== "string") {
    throw new ConfigError(`${where}.${key} must be a string`);
  }
  return value;
}

function readColour(
  table: Record<string, unknown>,
  key: string,
  where: string,
  fallback: string,
  palette: Map<string, string>,
): string {
  const value = readString(table, key, where, fallback);
  if (HEX_COLOUR.test(value)) {
    return value;
  }
  const resolved = palette.get(value);
  if (resolved === undefined) {
    throw new ConfigError(
      `${where}.${key} "${value}" is neither a hex colour (#RRGGBB) nor a palette name (${[...palette.keys()].join(", ")})`,
    );
  }
  return resolved;
}

function readIcon(
  table: Record<string, unknown>,
  where: string,
  palette: Map<string, string>,
  defaultColour: string,
): IconSpec {
  const icon = readString(table, "icon", where);
  const length = [...icon].length;
  if (length < 1 || length > 2) {
    throw new ConfigError(
      `${where}.icon must be one icon character, for example "\\uE19F"`,
    );
  }
  const font = readString(table, "font", where, "lucide");
  if (!FONT_NAMES.includes(font as FontName)) {
    throw new ConfigError(
      `${where}.font must be one of: ${FONT_NAMES.join(", ")}`,
    );
  }
  return {
    icon,
    font: font as FontName,
    colour: readColour(table, "colour", where, defaultColour, palette),
  };
}

/**
 * Validate the parsed TOML document and resolve palette colour names.
 * Unknown keys are errors, so a typing error never disappears silently.
 */
export function parseStarterConfig(
  document: unknown,
  palette: Map<string, string>,
): StarterConfig {
  const root = expectTable(document, "configuration");
  rejectUnknownKeys(root, ["bar", "close", "profiles"], "configuration");

  const barTable = expectTable(root["bar"] ?? {}, "[bar]");
  rejectUnknownKeys(
    barTable,
    [
      "timeout_seconds",
      "icon_pixels",
      "icon_offset_pixels",
      "label_pixels",
      "item_height_pixels",
      "width_pixels",
      "top_offset_pixels",
      "show_labels",
    ],
    "[bar]",
  );
  const bar: BarSettings = {
    timeoutSeconds: readInteger(
      barTable,
      "timeout_seconds",
      "bar",
      30,
      1,
      3600,
    ),
    iconPixels: readInteger(barTable, "icon_pixels", "bar", 48, 8, 256),
    iconOffsetPixels: readInteger(
      barTable,
      "icon_offset_pixels",
      "bar",
      8,
      -64,
      64,
    ),
    labelPixels: readInteger(barTable, "label_pixels", "bar", 14, 6, 64),
    itemHeightPixels: readInteger(
      barTable,
      "item_height_pixels",
      "bar",
      72,
      16,
      512,
    ),
    widthPixels: readInteger(barTable, "width_pixels", "bar", 152, 16, 1024),
    topOffsetPixels: readInteger(
      barTable,
      "top_offset_pixels",
      "bar",
      30,
      0,
      1024,
    ),
    showLabels: readBoolean(barTable, "show_labels", "bar", true),
  };
  if (bar.iconPixels > bar.itemHeightPixels) {
    throw new ConfigError(
      "bar.icon_pixels must not be larger than bar.item_height_pixels",
    );
  }

  const closeTable = expectTable(root["close"] ?? {}, "[close]");
  rejectUnknownKeys(closeTable, ["icon", "font", "colour"], "[close]");
  const close = readIcon(
    { icon: "\uE1B2", ...closeTable },
    "close",
    palette,
    palette.get("red") ?? "#FF7D6C",
  );

  const profileList = root["profiles"];
  if (!Array.isArray(profileList) || profileList.length === 0) {
    throw new ConfigError("add at least one [[profiles]] entry");
  }
  const seen = new Set<string>();
  const profiles = profileList.map((entry: unknown, index): ProfileSpec => {
    const where = `profiles[${String(index)}]`;
    const table = expectTable(entry, where);
    rejectUnknownKeys(
      table,
      ["label", "directory", "icon", "font", "colour"],
      where,
    );
    const label = readString(table, "label", where);
    const labelLength = [...label].length;
    if (labelLength < 1 || labelLength > MAX_LABEL_LENGTH) {
      throw new ConfigError(
        `${where}.label "${label}" must have 1 to ${String(MAX_LABEL_LENGTH)} characters`,
      );
    }
    if (/["%\n\r]/.test(label)) {
      throw new ConfigError(
        `${where}.label must not contain ", %, or line breaks`,
      );
    }
    const directory = readString(table, "directory", where);
    if (!PROFILE_DIRECTORY.test(directory)) {
      throw new ConfigError(
        `${where}.directory "${directory}" must be a Chrome profile folder name such as "Default" or "Profile 1"`,
      );
    }
    if (seen.has(directory)) {
      throw new ConfigError(`${where}.directory "${directory}" is used twice`);
    }
    seen.add(directory);
    return {
      label,
      directory,
      ...readIcon(
        table,
        where,
        palette,
        palette.get("foreground") ?? "#D2D0CB",
      ),
    };
  });

  return { bar, close, profiles };
}

/** Read one section of a Polybar .ini file as key/value pairs. */
export function parseIniSection(
  text: string,
  section: string,
): Map<string, string> {
  const values = new Map<string, string>();
  let current = "";
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (line === "" || line.startsWith(";") || line.startsWith("#")) {
      continue;
    }
    const header = /^\[(.+)\]$/.exec(line);
    if (header !== null) {
      current = header[1] ?? "";
      continue;
    }
    const separator = line.indexOf("=");
    if (current !== section || separator < 0) {
      continue;
    }
    const key = line.slice(0, separator).trim();
    let value = line.slice(separator + 1).trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.slice(1, -1);
    }
    values.set(key, value);
  }
  return values;
}

/** Resolve ${colours.name} references and keep only hex colours. */
export function resolvePalette(raw: Map<string, string>): Map<string, string> {
  const resolve = (key: string, depth: number): string | undefined => {
    const value = raw.get(key);
    const reference =
      value === undefined ? null : /^\$\{colours\.([\w-]+)\}$/.exec(value);
    if (reference === null || depth > 10) {
      return value;
    }
    return resolve(reference[1] ?? "", depth + 1);
  };
  const palette = new Map<string, string>();
  for (const key of raw.keys()) {
    const value = resolve(key, 0);
    if (value !== undefined && HEX_COLOUR.test(value)) {
      palette.set(key, value);
    }
  }
  return palette;
}

/**
 * Replace the size and the vertical offset of a Polybar font pattern
 * ("family:style=...:size=10;2") with a pixel size and a pixel offset.
 */
export function scaleFont(
  pattern: string,
  pixels: number,
  offset: number,
): string {
  const face = pattern.split(";")[0] ?? "";
  const parts = face
    .split(":")
    .filter((part) => !/^(?:size|pixelsize)=/.test(part));
  return `${parts.join(":")}:pixelsize=${String(pixels)};${String(offset)}`;
}

function loadPalette(): Map<string, string> {
  const file = path.join(POLYBAR_CONFIG_DIR, "01-colours.ini");
  return resolvePalette(parseIniSection(readFileSync(file, "utf8"), "colours"));
}

function loadTheme(config: StarterConfig, palette: Map<string, string>): Theme {
  const file = path.join(POLYBAR_CONFIG_DIR, "01-fonts.ini");
  const fonts = parseIniSection(readFileSync(file, "utf8"), "fonts");
  const pick = (name: FontName | "text"): string => {
    const value = fonts.get(FONT_KEYS[name]);
    if (value === undefined) {
      throw new ConfigError(`${file} has no "${FONT_KEYS[name]}" font`);
    }
    return name === "text"
      ? scaleFont(value, config.bar.labelPixels, 0)
      : scaleFont(value, config.bar.iconPixels, config.bar.iconOffsetPixels);
  };
  return {
    background: palette.get("background") ?? "#17191B",
    foreground: palette.get("foreground") ?? "#D2D0CB",
    border: palette.get("selection") ?? "#2E3236",
    fonts: {
      text: pick("text"),
      lucide: pick("lucide"),
      nerd: pick("nerd"),
      brands: pick("brands"),
    },
  };
}

export function loadConfig(configFile: string): StarterConfig {
  let text: string;
  try {
    text = readFileSync(configFile, "utf8");
  } catch (error) {
    throw new ConfigError(
      `cannot read ${configFile}: ${(error as Error).message}`,
    );
  }
  let document: unknown;
  try {
    document = parseToml(text);
  } catch (error) {
    throw new ConfigError(
      `${configFile} is not valid TOML: ${(error as Error).message}`,
    );
  }
  try {
    return parseStarterConfig(document, loadPalette());
  } catch (error) {
    if (error instanceof ConfigError) {
      throw new ConfigError(`${configFile}: ${error.message}`);
    }
    throw error;
  }
}

// ---------------------------------------------------------------------------
// Layout and Polybar configuration
// ---------------------------------------------------------------------------

/** Parse `polybar --list-monitors`; prefer the primary monitor. */
export function parseMonitors(output: string): Monitor | null {
  let first: Monitor | null = null;
  for (const line of output.split(/\r?\n/)) {
    const match = /^(\S+?): (\d+)x(\d+)\+-?\d+\+-?\d+(.*)$/.exec(line.trim());
    if (match === null) {
      continue;
    }
    const monitor: Monitor = {
      name: match[1] ?? "",
      width: Number(match[2]),
      height: Number(match[3]),
    };
    if ((match[4] ?? "").includes("primary")) {
      return monitor;
    }
    first ??= monitor;
  }
  return first;
}

function detectMonitor(): Monitor {
  const result = spawnSync("polybar", ["--list-monitors"], {
    encoding: "utf8",
  });
  if (result.error !== undefined) {
    throw new ConfigError(`cannot run polybar: ${result.error.message}`);
  }
  const monitor = parseMonitors(result.stdout);
  if (monitor === null) {
    throw new ConfigError(
      `polybar --list-monitors found no monitor: ${result.stderr.trim() || result.stdout.trim()}`,
    );
  }
  return monitor;
}

export interface BarLayout {
  name: string;
  offsetY: number;
  height: number;
  kind: "profile" | "filler" | "close";
  profile?: ProfileSpec;
}

/** Profiles from the top, the close button at the bottom, a filler between. */
export function layoutBars(
  config: StarterConfig,
  monitor: Monitor,
): BarLayout[] {
  const { itemHeightPixels: height, topOffsetPixels: top } = config.bar;
  const closeY = monitor.height - height;
  const fillerY = top + config.profiles.length * height;
  if (fillerY > closeY) {
    throw new ConfigError(
      `${String(config.profiles.length)} profiles do not fit on ${monitor.name} (${String(monitor.height)} pixels high); reduce bar.item_height_pixels or the number of profiles`,
    );
  }
  const bars: BarLayout[] = config.profiles.map((profile, index) => ({
    name: `${BAR_PREFIX}-p${String(index)}`,
    offsetY: top + index * height,
    height,
    kind: "profile",
    profile,
  }));
  if (closeY > fillerY) {
    bars.push({
      name: `${BAR_PREFIX}-filler`,
      offsetY: fillerY,
      height: closeY - fillerY,
      kind: "filler",
    });
  }
  bars.push({
    name: `${BAR_PREFIX}-close`,
    offsetY: closeY,
    height,
    kind: "close",
  });
  return bars;
}

function iconMarkup(spec: IconSpec): string {
  return `%{T${String(FONT_TAGS[spec.font])}}%{F${spec.colour}}${spec.icon}%{F-}%{T-}`;
}

/**
 * Render the Polybar configuration for all bars. `command` is the shell
 * prefix that runs this script; click handlers append their action to it.
 */
export function renderPolybarConfig(
  config: StarterConfig,
  monitor: Monitor,
  theme: Theme,
  command: string,
): string {
  const lines: string[] = [
    "; Generated by configs/session/browser-starter/browser-starter.ts.",
    "; Do not edit: change browser-starter.toml instead.",
    "",
    `[bar/${BAR_PREFIX}-base]`,
    `monitor = ${monitor.name}`,
    `width = ${String(config.bar.widthPixels)}`,
    "offset-x = 0",
    "override-redirect = true",
    "enable-ipc = false",
    `wm-name = ${BAR_PREFIX}`,
    `background = ${theme.background}`,
    `foreground = ${theme.foreground}`,
    "border-right-size = 1",
    `border-right-color = ${theme.border}`,
    "padding = 0",
    "module-margin = 0",
    "cursor-click = pointer",
    `font-0 = "${theme.fonts.text}"`,
    `font-1 = "${theme.fonts.lucide}"`,
    `font-2 = "${theme.fonts.nerd}"`,
    `font-3 = "${theme.fonts.brands}"`,
  ];

  // Lucide glyphs have about 1/4 icon size of empty space on each side, so
  // the visible gap between icon and label is larger than this offset.
  const gap = Math.round(config.bar.labelPixels * 0.3);

  for (const bar of layoutBars(config, monitor)) {
    const centred = bar.kind !== "profile" || !config.bar.showLabels;
    lines.push(
      "",
      `[bar/${bar.name}]`,
      `inherit = bar/${BAR_PREFIX}-base`,
      `height = ${String(bar.height)}`,
      `offset-y = ${String(bar.offsetY)}`,
      `${centred ? "modules-center" : "modules-left"} = ${bar.name}`,
    );
    if (!centred) {
      // Polybar 3.7 reads a plain number as a count of spaces: use "px".
      lines.push("padding-left = 12px");
    }
    if (bar.kind === "close") {
      lines.push("border-top-size = 1", `border-top-color = ${theme.border}`);
    }

    lines.push(
      "",
      `[module/${bar.name}]`,
      "type = custom/text",
      "format = <label>",
    );
    if (bar.kind === "profile" && bar.profile !== undefined) {
      const profile = bar.profile;
      const label = config.bar.showLabels
        ? `${iconMarkup(profile)}%{O${String(gap)}}%{T${String(FONT_TAGS.text)}}${profile.label}%{T-}`
        : iconMarkup(profile);
      lines.push(
        `label = "${label}"`,
        `click-left = ${command} --launch ${shellQuote(profile.directory)}`,
      );
    } else if (bar.kind === "close") {
      lines.push(
        `label = "${iconMarkup(config.close)}"`,
        `click-left = ${command} --close`,
      );
    } else {
      // Polybar needs a module with content; a space keeps the filler empty.
      lines.push('label = " "', `click-left = ${command} --close`);
    }
  }
  return `${lines.join("\n")}\n`;
}

function scriptCommand(configFile: string): string[] {
  const command = [process.execPath, SCRIPT_PATH];
  if (path.resolve(configFile) !== DEFAULT_CONFIG_FILE) {
    command.push("--config", path.resolve(configFile));
  }
  return command;
}

// ---------------------------------------------------------------------------
// Chrome profiles
// ---------------------------------------------------------------------------

/** Chrome profiles from `Local State`: folder name to display name. */
function readChromeProfiles(): Map<string, string> | null {
  const file = path.join(chromeUserDataDirectory(), "Local State");
  try {
    const document = JSON.parse(readFileSync(file, "utf8")) as {
      profile?: { info_cache?: Record<string, { name?: string }> };
    };
    const profiles = new Map<string, string>();
    for (const [directory, info] of Object.entries(
      document.profile?.info_cache ?? {},
    )) {
      profiles.set(directory, info.name ?? "");
    }
    return profiles;
  } catch {
    return null;
  }
}

function warnMissingProfiles(config: StarterConfig): void {
  const known = readChromeProfiles();
  if (known === null) {
    debug(
      `no Chrome Local State in ${chromeUserDataDirectory()}; cannot check profiles`,
    );
    return;
  }
  for (const profile of config.profiles) {
    if (!known.has(profile.directory)) {
      warn(
        `Chrome profile folder "${profile.directory}" (${profile.label}) does not exist yet; Chrome creates a new, empty profile on first start`,
      );
    }
  }
}

function findChrome(): string {
  for (const name of ["google-chrome-stable", "google-chrome"]) {
    const found = findExecutable(name);
    if (found !== null) {
      return found;
    }
  }
  throw new ConfigError(
    "Google Chrome is not installed (no google-chrome-stable or google-chrome on PATH)",
  );
}

// ---------------------------------------------------------------------------
// Session state
// ---------------------------------------------------------------------------

function readState(): SessionState | null {
  try {
    return JSON.parse(readFileSync(stateFile(), "utf8")) as SessionState;
  } catch {
    return null;
  }
}

function writeState(state: SessionState): void {
  mkdirSync(stateDirectory(), { recursive: true, mode: 0o700 });
  writeFileSync(stateFile(), `${JSON.stringify(state, null, 2)}\n`, {
    mode: 0o600,
  });
}

/** Polybar processes of a session that are still running. */
function livePolybars(state: SessionState): number[] {
  return state.polybarPids.filter(
    (pid) => isAlive(pid) && commandLine(pid).includes(state.polybarConfig),
  );
}

function isOpen(state: SessionState | null): state is SessionState {
  return state !== null && livePolybars(state).length > 0;
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

function closeSession(sessionToken: string | null): void {
  const state = readState();
  if (state === null) {
    debug("no open browser starter");
    return;
  }
  if (sessionToken !== null && state.token !== sessionToken) {
    debug("the timer belongs to an older session; nothing to close");
    return;
  }
  sessionLogFile = state.logFile;

  for (const pid of livePolybars(state)) {
    debug(`stopping polybar ${String(pid)}`);
    try {
      process.kill(pid, "SIGTERM");
    } catch {
      // Already gone.
    }
  }

  const timer = state.timerPid;
  if (
    timer !== null &&
    timer !== process.pid &&
    commandLine(timer).includes(state.token)
  ) {
    debug(`stopping timer ${String(timer)}`);
    try {
      // The timer is a process group leader (sh and its sleep).
      process.kill(-timer, "SIGTERM");
    } catch {
      // Already gone.
    }
  }

  rmSync(state.polybarConfig, { force: true });
  rmSync(stateFile(), { force: true });
  debug("closed");
}

async function openSession(configFile: string): Promise<void> {
  const logDir = logDirectory();
  mkdirSync(logDir, { recursive: true });
  sessionLogFile = path.join(logDir, `${timestamp()}.log`);

  const config = loadConfig(configFile);
  warnMissingProfiles(config);
  const monitor = detectMonitor();
  const theme = loadTheme(config, loadPalette());
  const command = scriptCommand(configFile).map(shellQuote).join(" ");
  const bars = layoutBars(config, monitor);

  const token = randomUUID();
  mkdirSync(stateDirectory(), { recursive: true, mode: 0o700 });
  const polybarConfig = path.join(stateDirectory(), `bars-${token}.ini`);
  writeFileSync(
    polybarConfig,
    renderPolybarConfig(config, monitor, theme, command),
    {
      mode: 0o600,
    },
  );
  debug(
    `wrote ${polybarConfig} for ${monitor.name} (${String(monitor.width)}x${String(monitor.height)})`,
  );

  const logFd = openSync(sessionLogFile, "a");
  const polybarPids: number[] = [];
  try {
    for (const bar of bars) {
      const child = spawn(
        "polybar",
        ["-l", "warning", "-c", polybarConfig, bar.name],
        {
          detached: true,
          stdio: ["ignore", logFd, logFd],
        },
      );
      child.on("error", (error) => {
        reportError(`cannot start polybar: ${error.message}`);
      });
      child.unref();
      if (child.pid !== undefined) {
        polybarPids.push(child.pid);
        debug(`started bar ${bar.name} as ${String(child.pid)}`);
      }
    }
  } finally {
    closeSync(logFd);
  }

  // The timer is `sh` running `sleep`, then it replaces itself with
  // `browser-starter --close --session TOKEN`. An old timer never closes a
  // newer session, because the token no longer matches.
  const timer = spawn(
    "/bin/sh",
    [
      "-c",
      'sleep "$1"; shift; exec "$@"',
      `${COMMAND_NAME}-timer`,
      String(config.bar.timeoutSeconds),
      ...scriptCommand(configFile),
      "--close",
      "--session",
      token,
    ],
    { detached: true, stdio: "ignore" },
  );
  timer.unref();

  const state: SessionState = {
    token,
    configFile: path.resolve(configFile),
    polybarConfig,
    polybarPids,
    timerPid: timer.pid ?? null,
    logFile: sessionLogFile,
    openedAt: new Date().toISOString(),
  };
  writeState(state);

  // Polybar exits at once on a configuration error. Report it, so a key
  // press never fails without a message.
  await sleep(STARTUP_CHECK_MS);
  if (readState()?.token !== token) {
    debug("closed during the startup check (click or toggle)");
    return;
  }
  const running = livePolybars(state).length;
  if (running < polybarPids.length) {
    reportError(
      `${String(polybarPids.length - running)} of ${String(polybarPids.length)} bars did not start; see ${sessionLogFile}`,
    );
    if (running === 0) {
      closeSession(token);
      process.exitCode = 1;
    }
    return;
  }
  debug(`open for ${String(config.bar.timeoutSeconds)} seconds`);
}

function launchProfile(configFile: string, directory: string): void {
  const state = readState();
  if (state !== null) {
    sessionLogFile = state.logFile;
  }
  const config = loadConfig(configFile);
  const profile = config.profiles.find(
    (entry) => entry.directory === directory,
  );
  if (profile === undefined) {
    throw new ConfigError(
      `profile folder "${directory}" is not configured in ${configFile}`,
    );
  }
  const chrome = findChrome();
  debug(
    `starting ${chrome} --profile-directory=${directory} (${profile.label})`,
  );
  const child = spawn(chrome, [`--profile-directory=${directory}`], {
    detached: true,
    stdio: "ignore",
  });
  child.on("error", (error) => {
    reportError(`cannot start Chrome: ${error.message}`);
  });
  child.unref();
  closeSession(null);
}

function listProfiles(configFile: string): void {
  const known = readChromeProfiles();
  if (known === null) {
    throw new ConfigError(
      `cannot read ${path.join(chromeUserDataDirectory(), "Local State")}`,
    );
  }
  let configured = new Set<string>();
  try {
    configured = new Set(
      loadConfig(configFile).profiles.map((profile) => profile.directory),
    );
  } catch (error) {
    warn((error as Error).message);
  }
  process.stdout.write("directory\tname\tconfigured\n");
  for (const [directory, name] of [...known].sort(([a], [b]) =>
    a.localeCompare(b),
  )) {
    process.stdout.write(
      `${directory}\t${name}\t${configured.has(directory) ? "yes" : "no"}\n`,
    );
  }
}

function checkConfig(configFile: string): void {
  const config = loadConfig(configFile);
  warnMissingProfiles(config);
  const monitor = detectMonitor();
  const theme = loadTheme(config, loadPalette());
  const command = scriptCommand(configFile).map(shellQuote).join(" ");
  process.stdout.write(renderPolybarConfig(config, monitor, theme, command));
}

// ---------------------------------------------------------------------------
// Command line
// ---------------------------------------------------------------------------

function helpText(): string {
  return `Usage: ${COMMAND_NAME} <command> [options]

Show a temporary side bar on the left edge of the screen. Each button starts
Google Chrome with one Chrome profile. The bar closes after a click, or after
bar.timeout_seconds (default: 30).

Commands:
  --toggle              Open the bar, or close it when it is open (Ctrl+Shift+Alt+B).
  --open                Open the bar. An open bar is closed and opened again.
  --close               Close the bar.
  --launch DIRECTORY    Start Chrome with the profile folder DIRECTORY, then close the bar.
  --list-profiles       Print the Chrome profiles (folder, name, configured).
  --check               Validate the configuration and print the generated Polybar config.

Options:
  --config FILE         Configuration file (default: ${path.relative(REPO_ROOT, DEFAULT_CONFIG_FILE)}).
  --session TOKEN       With --close: close only this session (used by the timer).
  --verbose             Print each step on stderr.
  --help                Show this help.

Files:
  Configuration   ${path.relative(REPO_ROOT, DEFAULT_CONFIG_FILE)}
  Logs            ~/.logs/browser-starter/YYYYMMDD-HHMMSS.log (one file for each opened bar)
  State           \${XDG_RUNTIME_DIR}/dnb-browser-starter/

Examples:
  ${COMMAND_NAME} --list-profiles
  ${COMMAND_NAME} --check
  ${COMMAND_NAME} --toggle
`;
}

type Command =
  | "toggle"
  | "open"
  | "close"
  | "launch"
  | "list-profiles"
  | "check";

interface Options {
  command: Command;
  configFile: string;
  directory: string | null;
  session: string | null;
}

function parseArguments(argv: string[]): Options | "help" {
  let command: Command | null = null;
  let configFile = DEFAULT_CONFIG_FILE;
  let directory: string | null = null;
  let session: string | null = null;

  const setCommand = (value: Command): void => {
    if (command !== null) {
      throw new UsageError(
        `use only one command (--${command} and --${value} given)`,
      );
    }
    command = value;
  };
  const takeValue = (flag: string, index: number): string => {
    const value = argv[index + 1];
    if (value === undefined || value.startsWith("--")) {
      throw new UsageError(`${flag} needs a value`);
    }
    return value;
  };

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    switch (argument) {
      case "--help":
      case "-h":
        return "help";
      case "--toggle":
      case "--open":
      case "--close":
      case "--list-profiles":
      case "--check":
        setCommand(argument.slice(2) as Command);
        break;
      case "--launch":
        setCommand("launch");
        directory = takeValue(argument, index);
        index += 1;
        break;
      case "--config":
        configFile = path.resolve(takeValue(argument, index));
        index += 1;
        break;
      case "--session":
        session = takeValue(argument, index);
        index += 1;
        break;
      case "--verbose":
        verbose = true;
        break;
      default:
        throw new UsageError(`unknown argument: ${String(argument)}`);
    }
  }

  if (command === null) {
    return "help";
  }
  if (session !== null && command !== "close") {
    throw new UsageError("--session works only with --close");
  }
  return { command, configFile, directory, session };
}

async function main(argv: string[]): Promise<number> {
  let options: Options | "help";
  try {
    options = parseArguments(argv);
  } catch (error) {
    process.stderr.write(
      `${COMMAND_NAME}: ${(error as Error).message}\n\n${helpText()}`,
    );
    return 2;
  }
  if (options === "help") {
    process.stdout.write(helpText());
    return 0;
  }

  try {
    switch (options.command) {
      case "toggle":
        if (isOpen(readState())) {
          closeSession(null);
        } else {
          closeSession(null);
          await openSession(options.configFile);
        }
        break;
      case "open":
        closeSession(null);
        await openSession(options.configFile);
        break;
      case "close":
        closeSession(options.session);
        break;
      case "launch":
        launchProfile(options.configFile, options.directory ?? "");
        break;
      case "list-profiles":
        listProfiles(options.configFile);
        break;
      case "check":
        checkConfig(options.configFile);
        break;
    }
  } catch (error) {
    reportError((error as Error).message);
    return 1;
  }
  return typeof process.exitCode === "number" ? process.exitCode : 0;
}

function isMainModule(): boolean {
  const entry = process.argv[1];
  if (entry === undefined) {
    return false;
  }
  try {
    return realpathSync(entry) === realpathSync(SCRIPT_PATH);
  } catch {
    return false;
  }
}

if (isMainModule()) {
  process.exitCode = await main(process.argv.slice(2));
}
