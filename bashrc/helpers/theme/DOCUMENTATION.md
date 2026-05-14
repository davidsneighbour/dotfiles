# `theme/` documentation

This file documents every file currently present in `bashrc/helpers/theme`.

Parent index: [`../INDEX.md`](../INDEX.md).

## Existing Markdown references

* [`color-steps.md`](./color-steps.md)
* [`color-steps.todo.md`](./color-steps.todo.md)

## Files

### `theme/color-steps.md`

Existing guide for the CSS colour variable generator.

Documentation status: this is an existing Markdown document. The implementation-specific documentation below references it rather than duplicating all prose.

### `theme/color-steps.todo.md`

Todo notes for future colour generator documentation/features; not implemented behaviour.

Documentation status: this is an existing Markdown document. The implementation-specific documentation below references it rather than duplicating all prose.

### `theme/color-steps.ts`

Generates HSL CSS custom properties for colour ramps.

CLI option notes:

* --count NUMBER — number of colours.
* --mode dark|light|none — correction mode.
* --rotate-channel hue|saturation|lightness — channel to interpolate; implemented even though existing markdown focuses on hue.
* --start-hue NUMBER — starting hue.
* --end-hue NUMBER — ending hue.
* --saturation NUMBER — base saturation.
* --lightness NUMBER — base lightness.
* --variable-prefix STRING — CSS custom property prefix.
* --start-index NUMBER — first variable index.
* --decimals NUMBER — decimal places.
* --no-corrections — disable contrast corrections.
* --help — show help.

Functions/methods defined:

* `fail`
* `clamp`
* `round`
* `parseNumber`
* `parseInteger`
* `parseThemeMode`
* `parseRotateChannel`
* `readRequiredValue`
* `padVariableIndex`
* `isRatioInZone`
* `applyCorrections`
* `interpolate`
* `toHslString`
* `generateRainbowCssVariables`
* `parseCliArgs`
* `isDirectRun`
* `main`

Requirements:

* Node.js with TypeScript execution support.
