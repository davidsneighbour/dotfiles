# Rainbow CSS variable generator

Generate a configurable rainbow colour lineup as CSS variables.

The default setup is tuned for a Dracula-like dark theme and creates a red-to-red rainbow using HSL colours. It is useful for folder colouring systems, Obsidian snippets, UI accents, category colours, or any setup where a predictable sequence of colours is better than manually picked values.

## What it does

The generator creates colours by interpolating through HSL values.

By default:

* hue rotates from `0` to `360`
* saturation stays mostly static
* lightness stays mostly static
* dark mode applies contrast corrections for the blue, purple, and magenta range
* light mode applies contrast corrections for the yellow and green range
* output is returned as CSS custom properties

Example:

```css
--folder-01: hsl(0 74% 44%);
--folder-02: hsl(40 68% 54%);
--folder-03: hsl(80 68% 54%);
--folder-04: hsl(120 68% 54%);
--folder-05: hsl(160 68% 54%);
--folder-06: hsl(200 68% 54%);
--folder-07: hsl(240 68% 54%);
--folder-08: hsl(280 76% 66%);
--folder-09: hsl(320 76% 66%);
--folder-10: hsl(360 74% 44%);
```

## Why HSL?

HSL is a good fit for this task because the colour dimensions are easy to reason about:

* `hue` controls the colour position on the wheel
* `saturation` controls colour intensity
* `lightness` controls perceived brightness

For a rainbow lineup, the most predictable model is to rotate hue while keeping saturation and lightness mostly stable.

The default formula is:

```txt
ratio = index / (count - 1)
hue = startHue + ratio * (endHue - startHue)
```

With the default range `0` to `360`, the first and last colours are both red.

## Contrast corrections

A mathematically even rainbow does not always look good on real backgrounds.

For dark themes:

* blue, violet, and magenta can become too dark
* the generator brightens that range

For light themes:

* yellow and green can become too weak or washed out
* the generator darkens that range

You can disable these corrections with `--no-corrections`.

## Usage

Run the script directly with Node.js:

```bash
node rainbow-css-vars.ts --count 10
```

Generate twelve Dracula-style dark colours:

```bash
node rainbow-css-vars.ts --count 12 --mode dark
```

Generate twelve light-theme colours:

```bash
node rainbow-css-vars.ts --count 12 --mode light
```

Generate a clean mathematical ramp without contrast corrections:

```bash
node rainbow-css-vars.ts --count 12 --mode none --no-corrections
```

Use a custom variable prefix:

```bash
node rainbow-css-vars.ts --count 12 --variable-prefix --folder
```

Use a custom hue range:

```bash
node rainbow-css-vars.ts --count 12 --start-hue 20 --end-hue 340
```

## CLI options

| Option                       |    Default | Description                          |
| ---------------------------- | ---------: | ------------------------------------ |
| `--count <number>`           |       `10` | Number of colours to generate.       |
| `--mode <dark\|light\|none>` |     `dark` | Correction mode.                     |
| `--start-hue <number>`       |        `0` | Starting hue.                        |
| `--end-hue <number>`         |      `360` | Ending hue.                          |
| `--saturation <number>`      |       `68` | Base saturation percentage.          |
| `--lightness <number>`       |       `54` | Base lightness percentage.           |
| `--variable-prefix <string>` | `--folder` | Prefix for generated CSS variables.  |
| `--start-index <number>`     |        `1` | First variable index.                |
| `--decimals <number>`        |        `1` | Decimal places for generated values. |
| `--no-corrections`           |   disabled | Disable theme contrast corrections.  |
| `--help`                     |          - | Show help output.                    |

## Examples

### Default Dracula-style dark palette

```bash
node rainbow-css-vars.ts --count 10 --mode dark
```

### Light mode palette

```bash
node rainbow-css-vars.ts --count 10 --mode light
```

### More muted colours

```bash
node rainbow-css-vars.ts --count 12 --mode dark --saturation 55 --lightness 50
```

### Brighter dark-theme colours

```bash
node rainbow-css-vars.ts --count 12 --mode dark --saturation 72 --lightness 58
```

### Red to red rainbow with no corrections

```bash
node rainbow-css-vars.ts --count 12 --mode none --no-corrections
```

### Purple to red range

```bash
node rainbow-css-vars.ts --count 8 --start-hue 270 --end-hue 360
```

## Using the output in CSS

Paste the generated variables into a theme selector:

```css
.theme-dark {
  --folder-01: hsl(0 74% 44%);
  --folder-02: hsl(40 68% 54%);
  --folder-03: hsl(80 68% 54%);
}
```

Then use the variables where needed:

```css
.example-item-1 {
  color: var(--folder-01);
}

.example-item-2 {
  color: var(--folder-02);
}
```

## Obsidian example

The generator only creates colour variables. The actual Obsidian folder matching can stay manual and semantic.

Example:

```css
.theme-dark {
  --folder-01: hsl(0 74% 44%);
  --folder-02: hsl(40 68% 54%);
  --folder-03: hsl(80 68% 54%);
}

.nav-folder-title[data-path^="Home"],
.tree-item.nav-folder:has(> .nav-folder-title[data-path^="Home"]) > .nav-folder-children {
  --prefix-color: var(--folder-01);
}

.nav-folder-title[data-path^="10"],
.tree-item.nav-folder:has(> .nav-folder-title[data-path^="10"]) > .nav-folder-children {
  --prefix-color: var(--folder-02);
}
```

This keeps folder identity separate from colour generation.

## Recommended workflow

1. Decide how many colour slots you need.
2. Generate the CSS variables.
3. Paste the variables into your theme block.
4. Keep your folder or item selectors separate.
5. Regenerate the variables when the number of slots changes.

Example:

```bash
node rainbow-css-vars.ts --count 12 --mode dark
node rainbow-css-vars.ts --count 12 --mode light
```

## Notes

* Use `0` to `360` when you want the first and last colour to both be red.
* Use `0` to `330` when you want the last colour to stop before red repeats.
* Use `--mode none --no-corrections` when you want a pure mathematical colour ramp.
* Use `--mode dark` for Dracula-like dark backgrounds.
* Use `--mode light` when the colours need to work on light backgrounds.
