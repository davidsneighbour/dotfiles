#!/usr/bin/env node
/**
 * extract.mjs
 * Extract evenly spaced screenshots from a video using ffmpeg/ffprobe.
 *
 * Modes:
 *  - single (DEFAULT): one ffmpeg run, faster, timestamps are approximate (fps-based sampling)
 *  - multi: N separate runs, slower, timestamps are more accurate (per-shot seek)
 *
 * Requirements:
 *  - Node.js v22+
 *  - ffmpeg + ffprobe in PATH
 */

import { spawn } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";

const DEFAULTS = {
  screens: 10,
  padding: 20,
  outdir: null,
  format: "png", // png | jpg | webp
  mode: "single", // single | multi
  jobs: 1,
  overwrite: false,
  verbose: false,
  dryRun: false,
  plan: false,

  jpgQuality: 1,
  pngCompression: 9,
  webpLossless: true,
  webpQuality: 90,

  scale: null,
};

const EXIT = {
  OK: 0,
  USAGE: 2,
  MISSING_DEP: 3,
  INVALID_INPUT: 4,
  RUNTIME: 5,
};

/**
 * @param {string} msg
 */
function log(msg) {
  process.stdout.write(`${msg}\n`);
}

/**
 * @param {string} msg
 */
function logErr(msg) {
  process.stderr.write(`${msg}\n`);
}

/**
 * @param {unknown} v
 * @returns {v is string}
 */
function isString(v) {
  return typeof v === "string";
}

/**
 * @param {string} name
 * @returns {Promise<boolean>}
 */
async function commandExists(name) {
  const whichCmd = process.platform === "win32" ? "where" : "which";
  return new Promise((resolve) => {
    const child = spawn(whichCmd, [name], { stdio: "ignore" });
    child.on("close", (code) => resolve(code === 0));
    child.on("error", () => resolve(false));
  });
}

/**
 * @param {string} cmd
 * @param {string[]} args
 * @param {{verbose:boolean, dryRun:boolean}} opts
 * @returns {Promise<{code:number, stdout:string, stderr:string}>}
 */
async function run(cmd, args, opts) {
  if (opts.dryRun) {
    log(`[dry-run] ${cmd} ${args.map((a) => JSON.stringify(a)).join(" ")}`);
    return { code: 0, stdout: "", stderr: "" };
  }

  return new Promise((resolve) => {
    const child = spawn(cmd, args, { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (d) => {
      const s = String(d);
      stdout += s;
      if (opts.verbose) process.stdout.write(s);
    });
    child.stderr.on("data", (d) => {
      const s = String(d);
      stderr += s;
      if (opts.verbose) process.stderr.write(s);
    });

    child.on("close", (code) => resolve({ code: code ?? 1, stdout, stderr }));
    child.on("error", (e) => resolve({ code: 1, stdout, stderr: String(e) }));
  });
}

/**
 * @param {string} videoPath
 * @param {{verbose:boolean, dryRun:boolean}} opts
 * @returns {Promise<number>}
 */
async function getDurationSeconds(videoPath, opts) {
  const args = [
    "-v",
    "error",
    "-show_entries",
    "format=duration",
    "-of",
    "default=nw=1:nk=1",
    videoPath,
  ];

  const res = await run("ffprobe", args, opts);
  if (res.code !== 0) throw new Error(`ffprobe failed (exit ${res.code}).`);

  const raw = res.stdout.trim();
  const duration = Number(raw);
  if (!Number.isFinite(duration) || duration <= 0) {
    throw new Error(`Could not parse duration from ffprobe output: "${raw}"`);
  }
  return duration;
}

/**
 * Evenly spaced timestamps including both ends of padded range.
 * Special case:
 *  - When padding === 0, the last timestamp MUST be 1 second before the end
 *    (to avoid failures when seeking exactly to duration).
 *
 * @param {number} duration
 * @param {number} screens
 * @param {number} padding
 * @returns {{start:number, end:number, effective:number, step:number, timestamps:number[], endAdjustmentSeconds:number}}
 */
function buildSamplingPlan(duration, screens, padding) {
  if (!Number.isFinite(duration) || duration <= 0) {
    throw new Error(`Invalid duration: ${String(duration)}`);
  }
  if (!Number.isFinite(screens) || screens < 2) {
    throw new Error(`--screens must be >= 2 (got ${String(screens)}).`);
  }
  if (!Number.isFinite(padding) || padding < 0) {
    throw new Error(`--padding must be >= 0 (got ${String(padding)}).`);
  }

  const start = padding;
  const endAdjustmentSeconds = padding === 0 ? (duration > 1 ? 1 : 0.001) : padding;

  const end = duration - endAdjustmentSeconds;
  const effective = end - start;

  if (effective <= 0) {
    throw new Error(
      `Padding too large or video too short. duration=${duration.toFixed(3)}s, padding=${padding}s, endAdjustment=${endAdjustmentSeconds}s => effective=${effective.toFixed(3)}s`,
    );
  }

  const step = effective / (screens - 1);

  /** @type {number[]} */
  const timestamps = [];
  for (let i = 0; i < screens; i += 1) {
    const t = start + step * i;
    const clamped = Math.min(Math.max(t, start), end);
    timestamps.push(clamped);
  }

  if (padding === 0) {
    const last = timestamps[timestamps.length - 1];
    if (Math.abs(last - duration) < 1e-6) {
      timestamps[timestamps.length - 1] = Math.max(0, duration - endAdjustmentSeconds);
    }
  }

  return { start, end, effective, step, timestamps, endAdjustmentSeconds };
}

/**
 * @param {number} t
 * @returns {string}
 */
function fmtTimeLabel(t) {
  return t.toFixed(3).replace(/\.?0+$/, "");
}

/**
 * @param {string} s
 * @returns {"single"|"multi"}
 */
function parseMode(s) {
  const v = s.toLowerCase();
  if (v === "single" || v === "multi") return v;
  throw new Error(`Invalid --mode "${s}" (use "single" or "multi").`);
}

/**
 * @param {string} s
 * @returns {"png"|"jpg"|"webp"}
 */
function parseFormat(s) {
  const v = s.toLowerCase();
  if (v === "jpeg") return "jpg";
  if (v === "png" || v === "jpg" || v === "webp") return v;
  throw new Error(`Invalid --format "${s}" (use png|jpg|webp).`);
}

/**
 * @param {string} s
 * @returns {number}
 */
function parseNumberStrict(s) {
  const n = Number(s);
  if (!Number.isFinite(n)) throw new Error(`Invalid number: "${s}"`);
  return n;
}

/**
 * @param {string} s
 * @returns {number}
 */
function parseIntStrict(s) {
  const n = Number(s);
  if (!Number.isFinite(n) || !Number.isInteger(n)) throw new Error(`Invalid integer: "${s}"`);
  return n;
}

/**
 * @param {string} s
 * @returns {number}
 */
function parseJobs(s) {
  const v = s.toLowerCase();
  if (v === "auto") {
    const cores = os.cpus().length;
    return Math.max(1, Math.min(cores, 4));
  }
  const n = parseIntStrict(s);
  if (n < 1) throw new Error(`--jobs must be >= 1 (got ${n}).`);
  return n;
}

/**
 * @param {{
 *  format:"png"|"jpg"|"webp",
 *  jpgQuality:number,
 *  pngCompression:number,
 *  webpLossless:boolean,
 *  webpQuality:number
 * }} q
 * @returns {string[]}
 */
function buildQualityArgs(q) {
  if (q.format === "jpg") return ["-q:v", String(q.jpgQuality)];
  if (q.format === "png") return ["-compression_level", String(q.pngCompression)];
  if (q.webpLossless) return ["-lossless", "1"];
  return ["-q:v", String(q.webpQuality)];
}

/**
 * @param {string|null} scale
 * @param {string} vf
 * @returns {string}
 */
function mergeScaleFilter(scale, vf) {
  if (!scale) return vf;
  if (vf.trim().length === 0) return `scale=${scale}`;
  return `${vf},scale=${scale}`;
}

/**
 * Single run (DEFAULT):
 * - Adds progress via -progress pipe:2 and counts "frame=" updates.
 *
 * @param {{
 *  videoPath:string,
 *  outDir:string,
 *  ext:"png"|"jpg"|"webp",
 *  padWidth:number,
 *  start:number,
 *  effective:number,
 *  step:number,
 *  screens:number,
 *  overwrite:boolean,
 *  verbose:boolean,
 *  dryRun:boolean,
 *  scale:string|null,
 *  jpgQuality:number,
 *  pngCompression:number,
 *  webpLossless:boolean,
 *  webpQuality:number
 * }} p
 */
async function extractSingleRun(p) {
  const outPattern = path.join(p.outDir, `frame_%0${p.padWidth}d.${p.ext}`);

  if (p.dryRun) {
    const argsPreview = [];
    argsPreview.push(p.overwrite ? "-y" : "-n");
    argsPreview.push("-hide_banner", "-loglevel", p.verbose ? "info" : "error");
    argsPreview.push("-progress", "pipe:2");
    argsPreview.push("-ss", String(p.start));
    argsPreview.push("-t", String(p.effective));
    argsPreview.push("-i", p.videoPath);

    let vf = `fps=1/${p.step}`;
    vf = mergeScaleFilter(p.scale, vf);

    argsPreview.push("-vf", vf);
    argsPreview.push("-frames:v", String(p.screens));
    argsPreview.push(
      ...buildQualityArgs({
        format: p.ext,
        jpgQuality: p.jpgQuality,
        pngCompression: p.pngCompression,
        webpLossless: p.webpLossless,
        webpQuality: p.webpQuality,
      }),
    );
    argsPreview.push(outPattern);

    await run("ffmpeg", argsPreview, { verbose: p.verbose, dryRun: p.dryRun });
    return;
  }

  return new Promise((resolve, reject) => {
    const args = [];
    args.push(p.overwrite ? "-y" : "-n");
    args.push("-hide_banner", "-loglevel", p.verbose ? "info" : "error");

    // Progress output as key=value pairs
    args.push("-progress", "pipe:2");

    args.push("-ss", String(p.start));
    args.push("-t", String(p.effective));
    args.push("-i", p.videoPath);

    let vf = `fps=1/${p.step}`;
    vf = mergeScaleFilter(p.scale, vf);

    args.push("-vf", vf);
    args.push("-frames:v", String(p.screens));

    args.push(
      ...buildQualityArgs({
        format: p.ext,
        jpgQuality: p.jpgQuality,
        pngCompression: p.pngCompression,
        webpLossless: p.webpLossless,
        webpQuality: p.webpQuality,
      }),
    );

    args.push(outPattern);

    const child = spawn("ffmpeg", args, { stdio: ["ignore", "ignore", "pipe"] });

    /** @type {number} */
    let lastFrame = 0;

    child.stderr.setEncoding("utf8");
    child.stderr.on("data", (chunk) => {
      // chunk contains key=value lines, e.g. "frame=12"
      const lines = chunk.split("\n");
      for (const line of lines) {
        const m = line.match(/^frame=(\d+)\s*$/);
        if (!m) continue;
        const f = Number(m[1]);
        if (Number.isFinite(f) && f > lastFrame) {
          // Each produced frame is one screencap in our workflow
          // Print exactly once per completed frame.
          for (let i = lastFrame + 1; i <= f; i += 1) {
            const idx = String(i).padStart(p.padWidth, "0");
            log(`[${idx}/${String(p.screens).padStart(p.padWidth, "0")}] screencap done`);
          }
          lastFrame = f;
        }
      }
    });

    child.on("error", (e) => reject(e));
    child.on("close", (code) => {
      if (code !== 0) return reject(new Error(`ffmpeg failed (single-run mode, exit ${code ?? 1}).`));
      resolve();
    });
  });
}

/**
 * Multi run (more accurate):
 * - Prints progress when each capture finishes
 *
 * @param {{
 *  videoPath:string,
 *  outDir:string,
 *  ext:"png"|"jpg"|"webp",
 *  timestamps:number[],
 *  padWidth:number,
 *  overwrite:boolean,
 *  verbose:boolean,
 *  dryRun:boolean,
 *  scale:string|null,
 *  jpgQuality:number,
 *  pngCompression:number,
 *  webpLossless:boolean,
 *  webpQuality:number
 * }} p
 * @param {number} jobs
 */
async function extractMultiRun(p, jobs) {
  /**
   * @param {number} index
   * @param {number} t
   */
  async function one(index, t) {
    const idx = String(index + 1).padStart(p.padWidth, "0");
    const tLabel = fmtTimeLabel(t);
    const outFile = path.join(p.outDir, `frame_${idx}_t${tLabel}.${p.ext}`);

    const args = [];
    args.push(p.overwrite ? "-y" : "-n");
    args.push("-hide_banner", "-loglevel", p.verbose ? "info" : "error");

    args.push("-i", p.videoPath);
    args.push("-ss", String(t));

    let vf = "";
    vf = mergeScaleFilter(p.scale, vf);
    if (vf.trim().length > 0) args.push("-vf", vf);

    args.push("-frames:v", "1");

    args.push(
      ...buildQualityArgs({
        format: p.ext,
        jpgQuality: p.jpgQuality,
        pngCompression: p.pngCompression,
        webpLossless: p.webpLossless,
        webpQuality: p.webpQuality,
      }),
    );

    args.push(outFile);

    const res = await run("ffmpeg", args, { verbose: p.verbose, dryRun: p.dryRun });
    if (res.code !== 0) throw new Error(`ffmpeg failed for t=${t}s (exit ${res.code}).`);

    log(`[${idx}/${String(p.timestamps.length).padStart(p.padWidth, "0")}] screencap done`);
    return outFile;
  }

  for (let i = 0; i < p.timestamps.length; i += jobs) {
    const chunk = p.timestamps.slice(i, i + jobs);
    await Promise.all(chunk.map((t, j) => one(i + j, t)));
  }
}

/**
 * @returns {string}
 */
function helpText() {
  return `
Usage:
  extract --video <file> [options]
  extract <file> [options]

Core options:
  --video <file>          Input video file (or pass as first positional arg)
  --screens <n>           Number of screenshots (default: ${DEFAULTS.screens}, minimum: 2)
  --padding <seconds>     Seconds to trim from both ends before sampling (default: ${DEFAULTS.padding})
                          Special case: if padding is 0, the last capture is at (duration - 1s)
  --mode <single|multi>   single = one ffmpeg run (DEFAULT, approximate timestamps)
                          multi  = N reopens (more accurate timestamps)
  --outdir <dir>          Output directory (default: ./<video>_screens/)
  --format <png|jpg|webp> Output format (default: ${DEFAULTS.format})

Quality options (max by default):
  --jpg-quality <n>       jpg only: ffmpeg -q:v (1 best, ~31 worst). default: ${DEFAULTS.jpgQuality}
  --png-compression <n>   png only: 0..9 (9 smallest, slowest). default: ${DEFAULTS.pngCompression}
  --webp-lossless         webp only: force lossless (DEFAULT)
  --no-webp-lossless      webp only: allow lossy
  --webp-quality <n>      webp lossy only: 0..100 (default: ${DEFAULTS.webpQuality})

Performance options:
  --jobs <n|auto>         multi only: concurrent ffmpeg workers (default: ${DEFAULTS.jobs})
  --scale <w:h>           Resize output, e.g. "1280:-1" (default: none)
  --overwrite             Overwrite existing files (default: off)

UX / debugging:
  --plan                  Print sampling plan + outputs, do not extract
  --dry-run               Print ffmpeg/ffprobe commands only
  --verbose               Show ffmpeg/ffprobe output
  --help                  Show this help
`.trimStart();
}

/**
 * @param {string[]} argv
 * @returns {{
 *  video:string|null,
 *  screens:number,
 *  padding:number,
 *  outdir:string|null,
 *  format:"png"|"jpg"|"webp",
 *  mode:"single"|"multi",
 *  jobs:number,
 *  overwrite:boolean,
 *  verbose:boolean,
 *  dryRun:boolean,
 *  plan:boolean,
 *  scale:string|null,
 *  jpgQuality:number,
 *  pngCompression:number,
 *  webpLossless:boolean,
 *  webpQuality:number,
 *  help:boolean
 * }}
 */
function parseArgs(argv) {
  /** @type {Record<string, string | boolean>} */
  const flags = {};
  /** @type {string[]} */
  const positional = [];

  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];

    if (a === "--help" || a === "-h") {
      flags.help = true;
      continue;
    }

    if (a === "--no-webp-lossless") {
      flags["webp-lossless"] = false;
      continue;
    }

    if (a === "--webp-lossless") {
      flags["webp-lossless"] = true;
      continue;
    }

    if (a.startsWith("--")) {
      const key = a.slice(2);
      const next = argv[i + 1];
      const isBool = next == null || next.startsWith("--");
      if (isBool) {
        flags[key] = true;
      } else {
        flags[key] = next;
        i += 1;
      }
      continue;
    }

    positional.push(a);
  }

  const video =
    (isString(flags.video) && flags.video) ||
    (positional.length > 0 ? positional[0] : null);

  const screens = isString(flags.screens) ? parseIntStrict(flags.screens) : DEFAULTS.screens;
  const padding = isString(flags.padding) ? parseNumberStrict(flags.padding) : DEFAULTS.padding;
  const outdir = isString(flags.outdir) ? flags.outdir : null;

  const mode = isString(flags.mode) ? parseMode(flags.mode) : DEFAULTS.mode;
  const format = isString(flags.format) ? parseFormat(flags.format) : DEFAULTS.format;

  const jobs = isString(flags.jobs) ? parseJobs(flags.jobs) : DEFAULTS.jobs;

  const scale = isString(flags.scale) ? flags.scale : null;

  const jpgQuality = isString(flags["jpg-quality"])
    ? parseIntStrict(flags["jpg-quality"])
    : DEFAULTS.jpgQuality;

  const pngCompression = isString(flags["png-compression"])
    ? parseIntStrict(flags["png-compression"])
    : DEFAULTS.pngCompression;

  const webpLossless =
    typeof flags["webp-lossless"] === "boolean" ? flags["webp-lossless"] : DEFAULTS.webpLossless;

  const webpQuality = isString(flags["webp-quality"])
    ? parseIntStrict(flags["webp-quality"])
    : DEFAULTS.webpQuality;

  return {
    video,
    screens,
    padding,
    outdir,
    format,
    mode,
    jobs,
    overwrite: flags.overwrite === true,
    verbose: flags.verbose === true,
    dryRun: flags["dry-run"] === true || flags.dryRun === true,
    plan: flags.plan === true,
    scale,
    jpgQuality,
    pngCompression,
    webpLossless,
    webpQuality,
    help: flags.help === true,
  };
}

/**
 * @param {unknown} e
 * @returns {string}
 */
function errToString(e) {
  if (e instanceof Error) return e.stack ?? e.message;
  return String(e);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.help || !args.video) {
    log(helpText());
    process.exit(args.video ? EXIT.OK : EXIT.USAGE);
  }

  const videoPath = path.resolve(args.video);
  if (!fs.existsSync(videoPath)) {
    logErr(`ERROR: video file not found: ${videoPath}`);
    log(helpText());
    process.exit(EXIT.INVALID_INPUT);
  }

  if (!(await commandExists("ffmpeg")) || !(await commandExists("ffprobe"))) {
    logErr("ERROR: missing dependency. This script requires ffmpeg and ffprobe in PATH.");
    logErr("Install on Ubuntu/Debian: sudo apt-get install -y ffmpeg");
    process.exit(EXIT.MISSING_DEP);
  }

  if (args.padding < 0) {
    logErr(`ERROR: --padding must be >= 0 (got ${args.padding}).`);
    process.exit(EXIT.INVALID_INPUT);
  }
  if (args.screens < 2) {
    logErr(`ERROR: --screens must be >= 2 (got ${args.screens}).`);
    process.exit(EXIT.INVALID_INPUT);
  }

  if (args.format === "jpg") {
    if (args.jpgQuality < 1 || args.jpgQuality > 31) {
      logErr(`ERROR: --jpg-quality must be 1..31 (got ${args.jpgQuality}).`);
      process.exit(EXIT.INVALID_INPUT);
    }
  }
  if (args.format === "png") {
    if (args.pngCompression < 0 || args.pngCompression > 9) {
      logErr(`ERROR: --png-compression must be 0..9 (got ${args.pngCompression}).`);
      process.exit(EXIT.INVALID_INPUT);
    }
  }
  if (args.format === "webp" && !args.webpLossless) {
    if (args.webpQuality < 0 || args.webpQuality > 100) {
      logErr(`ERROR: --webp-quality must be 0..100 (got ${args.webpQuality}).`);
      process.exit(EXIT.INVALID_INPUT);
    }
  }

  const baseName = path.basename(videoPath, path.extname(videoPath));
  const outDir =
    args.outdir != null ? path.resolve(args.outdir) : path.resolve(`${baseName}_screens`);
  if (!args.dryRun) fs.mkdirSync(outDir, { recursive: true });

  const duration = await getDurationSeconds(videoPath, { verbose: args.verbose, dryRun: args.dryRun });
  const plan = buildSamplingPlan(duration, args.screens, args.padding);
  const padWidth = String(args.screens).length;

  const qualitySummary =
    args.format === "jpg"
      ? `jpg q=${args.jpgQuality}`
      : args.format === "png"
        ? `png compression=${args.pngCompression} (lossless)`
        : args.webpLossless
          ? "webp lossless"
          : `webp lossy q=${args.webpQuality}`;

  log(`Video:    ${videoPath}`);
  log(`Duration: ${duration.toFixed(3)}s`);
  log(`Mode:     ${args.mode}${args.mode === "multi" ? ` (jobs=${args.jobs})` : ""}`);
  log(`Format:   ${args.format} (${qualitySummary})`);
  log(`Screens:  ${args.screens}`);
  log(`Padding:  ${args.padding}s`);
  log(`Range:    ${plan.start.toFixed(3)}s .. ${plan.end.toFixed(3)}s (effective ${plan.effective.toFixed(3)}s)`);
  log(`Step:     ${plan.step.toFixed(3)}s`);
  if (args.padding === 0) {
    log(`Note:     padding=0 -> end adjusted by ${plan.endAdjustmentSeconds}s to avoid end-of-file capture failure`);
  }
  if (args.scale) log(`Scale:    ${args.scale}`);
  log(`Output:   ${outDir}`);
  log("");

  log("Planned captures:");
  for (let i = 0; i < plan.timestamps.length; i += 1) {
    const idx = String(i + 1).padStart(padWidth, "0");
    const t = plan.timestamps[i];
    const tLabel = fmtTimeLabel(t);
    const file = path.join(outDir, `frame_${idx}_t${tLabel}.${args.format}`);
    log(`  ${idx}: t~${t.toFixed(3)}s -> ${file}`);
  }

  const metaFile = path.join(outDir, "extract-meta.json");
  if (!args.dryRun) {
    fs.writeFileSync(
      metaFile,
      `${JSON.stringify(
        {
          video: videoPath,
          durationSeconds: duration,
          mode: args.mode,
          format: args.format,
          quality: {
            jpgQuality: args.jpgQuality,
            pngCompression: args.pngCompression,
            webpLossless: args.webpLossless,
            webpQuality: args.webpQuality,
          },
          screens: args.screens,
          paddingSeconds: args.padding,
          endAdjustmentSeconds: plan.endAdjustmentSeconds,
          startSeconds: plan.start,
          endSeconds: plan.end,
          effectiveSeconds: plan.effective,
          stepSeconds: plan.step,
          timestampsPlanned: plan.timestamps,
          scale: args.scale,
          createdAt: new Date().toISOString(),
        },
        null,
        2,
      )}\n`,
      "utf8",
    );
  }

  if (args.plan) {
    log(`\nPlan only. Metadata: ${metaFile}`);
    process.exit(EXIT.OK);
  }

  log("");

  try {
    if (args.mode === "single") {
      log("Extracting (single-run mode)...");
      await extractSingleRun({
        videoPath,
        outDir,
        ext: args.format,
        padWidth,
        start: plan.start,
        effective: plan.effective,
        step: plan.step,
        screens: args.screens,
        overwrite: args.overwrite,
        verbose: args.verbose,
        dryRun: args.dryRun,
        scale: args.scale,
        jpgQuality: args.jpgQuality,
        pngCompression: args.pngCompression,
        webpLossless: args.webpLossless,
        webpQuality: args.webpQuality,
      });

      // Rename outputs to include planned timestamps
      if (!args.dryRun) {
        for (let i = 0; i < plan.timestamps.length; i += 1) {
          const idx = String(i + 1).padStart(padWidth, "0");
          const src = path.join(outDir, `frame_${idx}.${args.format}`);
          const tLabel = fmtTimeLabel(plan.timestamps[i]);
          const dst = path.join(outDir, `frame_${idx}_t${tLabel}.${args.format}`);
          if (fs.existsSync(src)) {
            fs.renameSync(src, dst);
            // Progress note for rename completion (optional)
            // log(`[${idx}/${String(args.screens).padStart(padWidth, "0")}] file renamed`);
          }
        }
      }
    } else {
      log(`Extracting (multi mode, jobs=${args.jobs})...`);
      await extractMultiRun(
        {
          videoPath,
          outDir,
          ext: args.format,
          timestamps: plan.timestamps,
          padWidth,
          overwrite: args.overwrite,
          verbose: args.verbose,
          dryRun: args.dryRun,
          scale: args.scale,
          jpgQuality: args.jpgQuality,
          pngCompression: args.pngCompression,
          webpLossless: args.webpLossless,
          webpQuality: args.webpQuality,
        },
        args.jobs,
      );
    }
  } catch (e) {
    logErr(`ERROR: ${errToString(e)}`);
    process.exit(EXIT.RUNTIME);
  }

  log(`\nDone. Metadata: ${metaFile}`);
  process.exit(EXIT.OK);
}

main().catch((e) => {
  logErr(`ERROR: ${errToString(e)}`);
  process.exit(EXIT.RUNTIME);
});
