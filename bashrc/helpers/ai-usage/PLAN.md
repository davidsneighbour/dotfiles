# Ai-usage implementation plan

<!-- markdownlint-disable MD025 -->

## Goal

Create a local TypeScript CLI named `ai-usage` that retrieves current usage-limit information from authenticated AI assistant CLIs and presents a compact terminal dashboard.

Initial providers:

* Claude Code
* OpenAI Codex

The tool is personal/local only. It does not need distribution infrastructure, multi-user support, or a web UI.

Running:

```bash
ai-usage
```

must retrieve fresh information every time.

---

## Core requirements

### Runtime

* Node.js 24+
* TypeScript
* ESM
* strict TypeScript
* npm
* TOML configuration
* local CLI executable named `ai-usage`

### Authentication

Do not manage provider credentials.

Use the existing authentication of:

```bash
claude
codex
```

If a provider is not authenticated, report that clearly without preventing other providers from loading.

### Configuration

Use:

```text
~/.config/ai-usage/config.toml
```

Initial configuration:

```toml
[providers.claude]
enabled = true

[providers.codex]
enabled = true
```

Keep configuration deliberately small.

---

# Architecture

Use provider adapters behind a common interface.

```text
src/
├── cli.ts
├── config.ts
├── types.ts
│
├── providers/
│   ├── provider.ts
│   ├── claude-code.ts
│   └── codex.ts
│
├── usage/
│   ├── health.ts
│   └── time.ts
│
├── renderers/
│   ├── terminal.ts
│   └── json.ts
│
└── commands/
    └── doctor.ts

tests/
├── fixtures/
│   ├── claude/
│   └── codex/
└── ...
```

Provider-specific parsing must stay entirely inside the provider adapter.

The rest of the application must not care how Claude or Codex obtain their usage information.

---

# Normalised data model

Do not model limits as "daily usage".

Providers may expose:

* rolling 5-hour sessions
* weekly limits
* calendar periods
* other future quota windows

Use a generic quota-window model.

```ts
export interface UsageProviderResult {
  provider: string;
  displayName: string;
  authenticated: boolean;
  collectedAt: string;

  limits: UsageLimit[];

  error?: string;
}

export interface UsageLimit {
  id: string;
  label: string;

  usedPercent?: number;
  remainingPercent?: number;

  window?: {
    type: "rolling" | "calendar" | "unknown";
    durationSeconds?: number;
    startedAt?: string;
    resetsAt?: string;
  };
}
```

Store timestamps internally as absolute ISO timestamps.

Human-readable relative times belong only in the renderer.

---

# Retrieving provider information

For each provider, investigate acquisition methods in this order:

1. official machine-readable CLI output
2. structured local/API data used by the authenticated CLI
3. non-interactive invocation of the provider's status command
4. parsing human-readable terminal output as a fallback

Avoid coupling the entire application to terminal screen scraping.

## Claude code

Investigate the data behind:

```text
/usage
```

Implement:

```ts
ClaudeCodeProvider
```

Responsibilities:

* detect `claude`
* determine authentication state
* retrieve current usage
* parse every reported quota window
* return normalised `UsageProviderResult`

## Codex

Investigate the data behind:

```text
/status
```

Implement:

```ts
CodexProvider
```

with the same responsibilities.

Do not assume that Codex or Claude will always expose exactly a 5-hour and weekly window.

---

# Terminal interface

The default command:

```bash
ai-usage
```

should immediately retrieve fresh information and render it.

Example:

```text
AI usage                                      updated 11:31

SERVICE       LIMIT        USED    LEFT    RESETS AT    RESETS IN
Claude Code   5-hour        60%     40%    13:43        2h 12m
Claude Code   weekly        41%     59%    Sun 08:00    3d 20h
Codex         5-hour        23%     77%    14:02        2h 31m
Codex         weekly        64%     36%    Mon 09:00    4d 21h

Overall
─────────────────────────────────────────────────────────────
Services available        2 / 2
Lowest remaining          36% — Codex weekly
Highest usage pressure    Codex weekly
Next reset                Claude Code 5-hour — 2h 12m
```

Include both:

```text
RESETS AT
```

and:

```text
RESETS IN
```

because each communicates something different.

`RESETS IN` should be human-readable:

```text
12m
1h 4m
2h 12m
1d 3h
4d 21h
```

Avoid verbose text such as:

```text
2 hours, 12 minutes
```

inside the table unless terminal width permits it.

---

# Usage-pressure colouring

Do not colour based solely on percentage consumed.

The useful question is:

> Are we consuming this quota faster than the quota window is progressing?

For every quota window where its start/reset time is known, calculate:

```text
elapsedRatio = elapsed time / total window duration
usageRatio   = used quota / total quota
```

Then compare the two.

For example, three hours into a five-hour window:

```text
elapsedRatio = 3 / 5 = 0.60
```

If usage is also:

```text
60%
```

then usage is exactly on pace.

That should be green.

## Pressure ratio

Define:

```text
pressureRatio = usageRatio / elapsedRatio
```

Examples:

```text
3 hours into 5 hours
60% used

0.60 / 0.60 = 1.00
```

Healthy.

```text
3 hours into 5 hours
80% used

0.80 / 0.60 = 1.33
```

Running significantly ahead of the available quota.

```text
3 hours into 5 hours
40% used

0.40 / 0.60 = 0.67
```

Comfortably below the expected consumption rate.

---

# Health classification

Start with configurable thresholds:

```toml
[health]
warning_ratio = 1.15
critical_ratio = 1.35
critical_remaining_percent = 10
```

Interpretation:

```text
pressure < 1.15
    green

pressure >= 1.15
    yellow

pressure >= 1.35
    red
```

Also force red when:

```text
remaining <= 10%
```

regardless of elapsed time.

This prevents an almost-exhausted quota from appearing healthy near the end of a window.

---

# Early-window handling

Pressure ratios can become misleading immediately after a reset.

For example:

```text
5 minutes into 5 hours
5% used
```

technically means usage is far ahead of elapsed time, even though there is no practical problem.

Introduce a grace period.

For example:

```toml
[health]
minimum_elapsed_percent = 10
```

Before 10% of the quota window has elapsed, classify primarily by absolute remaining quota instead of pace.

That means a five-hour session gets approximately a 30-minute grace period.

---

# Weekly limits

Use exactly the same algorithm for weekly limits.

Example:

```text
4 days into 7 days
57% of time elapsed
55% of quota used
```

Healthy.

```text
2 days into 7 days
29% of time elapsed
70% of quota used
```

Red.

This makes session and weekly limits directly comparable without pretending their actual quotas are equivalent.

---

# Colour application

Use terminal colours only when stdout is a TTY.

Respect:

```text
NO_COLOR
```

Use colour semantically:

```text
green    healthy
yellow   elevated
red      critical
dim      unavailable / unknown
```

Colour the most useful values, preferably:

```text
USED
LEFT
```

or a small status indicator.

Do not colour entire rows aggressively.

Example:

```text
Claude Code   5-hour    60%    40%    13:43    2h 12m    ● healthy
Codex         weekly    76%    24%    Mon      4d 21h    ● elevated
```

The status text ensures the information still works without colour.

---

# Unknown timing information

Sometimes a provider may expose:

```text
64% used
```

but not provide enough information to determine when the quota window began.

In that case do not invent a pressure score.

Fall back to absolute remaining quota.

Suggested defaults:

```text
remaining >= 40%    healthy
remaining 15–39%    elevated
remaining < 15%     critical
```

Mark internally that the health score is based on:

```text
absolute
```

rather than:

```text
pace
```

---

# Summary

The overall summary should not average provider percentages.

Instead calculate operational signals:

```text
Services available
Lowest remaining quota
Highest pressure
Next reset
Critical limits
```

For example:

```text
Overall
────────────────────────────────────────
Services available        2 / 2
Critical limits           none
Highest pressure          Codex weekly
Lowest remaining          36%
Next reset                Claude 5-hour — 2h 12m
```

The most important aggregate metric is:

```text
highest pressure
```

rather than average usage.

---

# Additional CLI commands

## JSON output

Provide:

```bash
ai-usage --json
```

This should expose the normalised raw information plus calculated health information.

Example structure:

```json
{
  "collectedAt": "2026-08-20T11:31:00+07:00",
  "providers": [],
  "summary": {}
}
```

This creates a reusable interface for future scripts without requiring another UI.

## Doctor

Provide:

```bash
ai-usage doctor
```

Example:

```text
Claude Code
  executable       ✓
  authenticated    ✓
  usage retrieval  ✓

Codex
  executable       ✓
  authenticated    ✓
  usage retrieval  ✓
```

Include provider CLI versions where possible.

---

# Error handling

Providers must fail independently.

For example:

```text
Claude Code   unavailable — authentication required
Codex         5-hour       24% used ...
```

`ai-usage` should still succeed sufficiently to display Codex.

Use a non-zero exit code only when appropriate, particularly:

```text
all configured providers failed
invalid configuration
internal application error
```

For `--json`, expose provider failures structurally instead of mixing diagnostics into stdout.

Send diagnostics to stderr.

---

# Command execution

Use Node's process execution APIs without shell interpolation.

Prefer:

```ts
spawn()
```

or:

```ts
execFile()
```

over:

```ts
exec()
```

Requirements:

* command timeout
* stdout capture
* stderr capture
* distinguish executable-not-found
* distinguish authentication errors
* distinguish parser incompatibility
* useful error messages

---

# Tests

Provider parsers must use fixtures.

Store representative provider responses under:

```text
tests/fixtures/
```

Test:

* authenticated response
* unauthenticated response
* multiple quota windows
* missing reset information
* changed/unknown fields
* malformed output
* provider command failure

Test health calculations separately.

Important boundary tests:

```text
usage pace exactly matches elapsed time
usage slightly ahead
usage significantly ahead
early-window grace period
less than 10% remaining
weekly window
reset time already passed
unknown start time
```

---

# Implementation order

## Phase 1 — project foundation

1. Initialise npm project.
2. Configure strict TypeScript and ESM.
3. Add executable `ai-usage` entry point.
4. Add TOML configuration loader.
5. Define normalised provider interfaces.
6. Implement safe command runner.

## Phase 2 — provider investigation

1. Determine the most stable machine-readable Claude Code usage source.
2. Capture representative Claude responses.
3. Determine the most stable machine-readable Codex usage source.
4. Capture representative Codex responses.

Do this investigation before writing substantial parser code.

## Phase 3 — provider adapters

 1. Implement Claude Code adapter.
 2. Implement Codex adapter.
 3. Add authentication and availability detection.
 4. Add fixture-based parser tests.

## Phase 4 — quota intelligence

 1. Implement reset-time calculations.
 2. Implement human-readable durations.
 3. Implement elapsed-window calculations.
 4. Implement pressure ratio.
 5. Implement health classification.
 6. Implement early-window grace period.
 7. Implement fallback classification for incomplete data.

## Phase 5 — terminal UI

 1. Implement table renderer.
 2. Add `RESETS AT`.
 3. Add `RESETS IN`.
 4. Add semantic colourisation.
 5. Respect `NO_COLOR` and non-TTY output.
 6. Add overall summary.

## Phase 6 — supporting interfaces

 1. Implement `--json`.
 2. Implement `doctor`.
 3. Add useful exit codes and stderr diagnostics.

## Phase 7 — hardening

 1. Test against real authenticated Claude Code.
 2. Test against real authenticated Codex.
 3. Verify reset calculations against provider UI.
 4. Verify colours at representative usage/time combinations.
 5. Document provider-specific data acquisition.
 6. Document what to inspect when an upstream CLI changes.

---

# Definition of done

The first version is complete when:

```bash
ai-usage
```

can be run from any directory and:

* loads `~/.config/ai-usage/config.toml`
* queries Claude Code
* queries Codex
* retrieves fresh quota information
* shows every available quota window
* shows percentage used
* shows percentage remaining
* shows absolute reset time
* shows human-readable time until reset
* evaluates whether consumption is ahead of or behind the quota window
* colours that health state appropriately
* provides an aggregate risk summary
* survives one provider being unavailable
* supports `--json`
* supports `ai-usage doctor`

The key design principle is that **health means usage relative to time elapsed**, not simply "how much quota has been consumed". That should make the terminal dashboard answer the useful question at a glance: *am I burning through this allowance too quickly?*
