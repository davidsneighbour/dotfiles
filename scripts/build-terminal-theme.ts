#!/usr/bin/env -S node --experimental-strip-types

// Generate renderer theme assets from the canonical terminal palette in
// bashrc/lib/00-core/dnb-core-ui-theme.bash.
//
// Outputs (configs/theme/dnb-terminal/):
//   glow/dracula-pro.json, glow/nosferatu.json   Glow (glamour) styles
//   bat/DNB Dracula Pro.tmTheme, bat/DNB Dracula Pro Nosferatu.tmTheme
//
// Usage:
//   node --experimental-strip-types scripts/build-terminal-theme.ts [--check]
//
// --check reports drift without writing files and exits 1 on drift.

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";

const ROOT = process.cwd();
const THEME_SOURCE = resolve(ROOT, "bashrc/lib/00-core/dnb-core-ui-theme.bash");
const OUTPUT_DIR = resolve(ROOT, "configs/theme/dnb-terminal");

type Palette = Record<string, string>;

type Variant = {
  id: "dracula-pro" | "nosferatu";
  batName: string;
  palette: Palette;
};

function parseBlock(source: string, arrayName: string): Palette {
  const start = source.indexOf(`declare -gA ${arrayName}=(`);
  if (start === -1) {
    throw new Error(`Missing ${arrayName} in ${THEME_SOURCE}`);
  }
  const end = source.indexOf("\n)", start);
  const block = source.slice(start, end);
  const palette: Palette = {};
  for (const match of block.matchAll(/^\s*\[(\w+)\]='(#[0-9A-F]{6})\|/gmu)) {
    const [, name, hex] = match;
    if (name !== undefined && hex !== undefined) {
      palette[name] = hex;
    }
  }
  return palette;
}

function color(palette: Palette, name: string): string {
  const value = palette[name];
  if (value === undefined) {
    throw new Error(`Palette has no ${name} row`);
  }
  return value;
}

function glowStyle(p: Palette): string {
  const c = (name: string): string => color(p, name);
  const style = {
    document: {
      block_prefix: "\n",
      block_suffix: "\n",
      color: c("Foreground"),
      margin: 2,
    },
    block_quote: {
      indent: 1,
      indent_token: "│ ",
      color: c("Comment"),
      italic: true,
    },
    paragraph: {},
    list: { level_indent: 2 },
    heading: { block_suffix: "\n", color: c("Cyan"), bold: true },
    h1: { prefix: "# ", color: c("Magenta"), bold: true },
    h2: { prefix: "## " },
    h3: { prefix: "### " },
    h4: { prefix: "#### " },
    h5: { prefix: "##### " },
    h6: { prefix: "###### ", color: c("Comment") },
    text: {},
    strikethrough: { crossed_out: true },
    emph: { italic: true, color: c("Yellow") },
    strong: { bold: true, color: c("Orange") },
    hr: { color: c("BrightBlack"), format: "\n--------\n" },
    item: { block_prefix: "• " },
    enumeration: { block_prefix: ". ", color: c("Cyan") },
    task: { ticked: "[✓] ", unticked: "[ ] " },
    link: { color: c("Blue"), underline: true },
    link_text: { color: c("Cyan"), bold: true },
    image: { color: c("Blue"), underline: true },
    image_text: { color: c("Cyan"), format: "Image: {{.text}} →" },
    code: {
      prefix: " ",
      suffix: " ",
      color: c("Green"),
      background_color: c("Selection"),
    },
    code_block: {
      color: c("Foreground"),
      margin: 2,
      chroma: {
        text: { color: c("Foreground") },
        error: { color: c("Foreground"), background_color: c("Red") },
        comment: { color: c("Comment") },
        comment_preproc: { color: c("Magenta") },
        keyword: { color: c("Magenta") },
        keyword_reserved: { color: c("Magenta") },
        keyword_namespace: { color: c("Magenta") },
        keyword_type: { color: c("Cyan"), italic: true },
        operator: { color: c("Magenta") },
        punctuation: { color: c("Foreground") },
        name: { color: c("Foreground") },
        name_builtin: { color: c("Cyan"), italic: true },
        name_tag: { color: c("Magenta") },
        name_attribute: { color: c("Green") },
        name_class: { color: c("Cyan") },
        name_constant: { color: c("Blue") },
        name_decorator: { color: c("Green") },
        name_function: { color: c("Green") },
        literal_number: { color: c("Blue") },
        literal_string: { color: c("Yellow") },
        literal_string_escape: { color: c("Magenta") },
        generic_deleted: { color: c("Red") },
        generic_emph: { italic: true },
        generic_inserted: { color: c("Green") },
        generic_strong: { bold: true },
        generic_subheading: { color: c("Comment") },
        background: { background_color: c("Background") },
      },
    },
    table: {},
    definition_list: {},
    definition_term: {},
    definition_description: { block_prefix: "\n→ " },
    html_block: {},
    html_span: {},
  };
  return `${JSON.stringify(style, null, 2)}\n`;
}

function escapeXml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function batTheme(name: string, p: Palette): string {
  const c = (key: string): string => color(p, key);
  const scopes: Array<[string, string, string, string?]> = [
    ["Comment", "comment", c("Comment")],
    ["String", "string", c("Yellow")],
    ["Number", "constant.numeric", c("Blue")],
    ["Built-in constant", "constant.language", c("Blue")],
    [
      "Constant",
      "constant.character, constant.other, variable.other.constant",
      c("Blue"),
    ],
    ["Keyword", "keyword, storage", c("Magenta")],
    ["Storage type", "storage.type, support.type", c("Cyan"), "italic"],
    [
      "Class name",
      "entity.name.class, entity.name.type, entity.other.inherited-class",
      c("Cyan"),
    ],
    ["Function name", "entity.name.function, support.function", c("Green")],
    ["Parameter", "variable.parameter", c("Orange"), "italic"],
    ["Tag name", "entity.name.tag", c("Magenta")],
    ["Attribute", "entity.other.attribute-name", c("Green")],
    ["Escape", "constant.character.escape", c("Magenta")],
    ["Heading", "markup.heading, entity.name.section", c("Magenta"), "bold"],
    ["Inserted", "markup.inserted", c("Green")],
    ["Deleted", "markup.deleted", c("Red")],
    ["Changed", "markup.changed", c("Orange")],
    ["Invalid", "invalid", c("Red")],
  ];
  const scopeXml = scopes
    .map(
      ([label, scope, fg, fontStyle]) => `    <dict>
      <key>name</key>
      <string>${escapeXml(label)}</string>
      <key>scope</key>
      <string>${escapeXml(scope)}</string>
      <key>settings</key>
      <dict>
        <key>foreground</key>
        <string>${fg}</string>${
          fontStyle === undefined
            ? ""
            : `
        <key>fontStyle</key>
        <string>${fontStyle}</string>`
        }
      </dict>
    </dict>`,
    )
    .join("\n");

  return `<?xml version="1.0" encoding="UTF-8"?>
<!-- Generated by scripts/build-terminal-theme.ts. Do not edit. -->
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>name</key>
  <string>${escapeXml(name)}</string>
  <key>settings</key>
  <array>
    <dict>
      <key>settings</key>
      <dict>
        <key>background</key>
        <string>${c("Background")}</string>
        <key>foreground</key>
        <string>${c("Foreground")}</string>
        <key>caret</key>
        <string>${c("Cursor")}</string>
        <key>selection</key>
        <string>${c("Selection")}</string>
        <key>lineHighlight</key>
        <string>${c("Selection")}</string>
        <key>gutterForeground</key>
        <string>${c("Comment")}</string>
      </dict>
    </dict>
${scopeXml}
  </array>
</dict>
</plist>
`;
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  if (args.includes("--help")) {
    process.stdout.write("Usage: build-terminal-theme.ts [--check]\n");
    return;
  }
  const unknown = args.filter((arg) => arg !== "--check");
  if (unknown.length > 0) {
    throw new Error(`Unknown argument: ${unknown.join(" ")}`);
  }
  const check = args.includes("--check");

  const source = await readFile(THEME_SOURCE, "utf8");
  const mainPalette = parseBlock(source, "__DNB_UI_PALETTE_MAIN");
  const nosferatu = parseBlock(source, "__DNB_UI_PALETTE_NOSFERATU");
  for (const [label, palette] of [
    ["main", mainPalette],
    ["Nosferatu", nosferatu],
  ] as const) {
    if (Object.keys(palette).length !== 30) {
      throw new Error(
        `Expected 30 ${label} palette rows, found ${Object.keys(palette).length}`,
      );
    }
  }

  const variants: Variant[] = [
    { id: "dracula-pro", batName: "DNB Dracula Pro", palette: mainPalette },
    {
      id: "nosferatu",
      batName: "DNB Dracula Pro Nosferatu",
      palette: nosferatu,
    },
  ];

  const outputs = new Map<string, string>();
  for (const variant of variants) {
    outputs.set(
      resolve(OUTPUT_DIR, "glow", `${variant.id}.json`),
      glowStyle(variant.palette),
    );
    outputs.set(
      resolve(OUTPUT_DIR, "bat", `${variant.batName}.tmTheme`),
      batTheme(variant.batName, variant.palette),
    );
  }

  let drift = false;
  for (const [path, content] of outputs) {
    let current = "";
    try {
      current = await readFile(path, "utf8");
    } catch {
      current = "";
    }
    if (current === content) {
      continue;
    }
    if (check) {
      drift = true;
      process.stderr.write(`Out of date: ${path}\n`);
      continue;
    }
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, content, "utf8");
    process.stderr.write(`Wrote ${path}\n`);
  }

  if (drift) {
    process.stderr.write("Run: npm run build:terminal-theme\n");
    process.exitCode = 1;
  }
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(`build-terminal-theme: ${message}\n`);
  process.exitCode = 1;
});
