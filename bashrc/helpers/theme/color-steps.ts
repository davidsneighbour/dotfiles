#!/usr/bin/env node

type ThemeMode = 'dark' | 'light' | 'none';
type HslChannel = 'hue' | 'saturation' | 'lightness';

type CorrectionZone = {
    name: string;
    fromRatio: number;
    toRatio: number;
    saturationOffset: number;
    lightnessOffset: number;
};

type RainbowColourOptions = {
    count: number;
    rotateChannel: HslChannel;
    startHue: number;
    endHue: number;
    saturation: number;
    lightness: number;
    mode: ThemeMode;
    variablePrefix: string;
    startIndex: number;
    decimals: number;
    corrections: boolean;
    darkCorrections: CorrectionZone[];
    lightCorrections: CorrectionZone[];
};

type CliConfig = RainbowColourOptions;

const DEFAULT_CONFIG: RainbowColourOptions = {
    count: 10,
    rotateChannel: 'hue',
    startHue: 0,
    endHue: 360,
    saturation: 68,
    lightness: 54,
    mode: 'dark',
    variablePrefix: '--folder',
    startIndex: 1,
    decimals: 1,
    corrections: true,
    darkCorrections: [
        {
            name: 'brighten cool colours',
            fromRatio: 0.64,
            toRatio: 0.99,
            saturationOffset: 8,
            lightnessOffset: 12,
        },
        {
            name: 'deepen red anchors',
            fromRatio: 0,
            toRatio: 0,
            saturationOffset: 6,
            lightnessOffset: -10,
        },
        {
            name: 'deepen closing red anchor',
            fromRatio: 1,
            toRatio: 1,
            saturationOffset: 6,
            lightnessOffset: -10,
        },
    ],
    lightCorrections: [
        {
            name: 'darken yellow and green range',
            fromRatio: 0.18,
            toRatio: 0.55,
            saturationOffset: -6,
            lightnessOffset: -8,
        },
        {
            name: 'lift cool range slightly',
            fromRatio: 0.64,
            toRatio: 0.99,
            saturationOffset: 6,
            lightnessOffset: 4,
        },
        {
            name: 'deepen red anchors',
            fromRatio: 0,
            toRatio: 0,
            saturationOffset: 4,
            lightnessOffset: -4,
        },
        {
            name: 'deepen closing red anchor',
            fromRatio: 1,
            toRatio: 1,
            saturationOffset: 4,
            lightnessOffset: -4,
        },
    ],
};

const HELP_TEXT = `
Generate rainbow CSS variables using HSL.

Usage:
  node rainbow-css-vars.ts --count 10
  node rainbow-css-vars.ts --count 12 --mode dark
  node rainbow-css-vars.ts --count 12 --mode light
  node rainbow-css-vars.ts --count 12 --start-hue 0 --end-hue 360
  node rainbow-css-vars.ts --count 12 --saturation 68 --lightness 54
  node rainbow-css-vars.ts --count 12 --variable-prefix --folder
  node rainbow-css-vars.ts --count 12 --no-corrections

Options:
  --count <number>              Amount of colours to generate. Default: 10.
  --mode <dark|light|none>      Correction mode. Default: dark.
  --start-hue <number>          Start hue. Default: 0.
  --end-hue <number>            End hue. Default: 360.
  --saturation <number>         Base saturation percentage. Default: 68.
  --lightness <number>          Base lightness percentage. Default: 54.
  --variable-prefix <string>    CSS variable prefix. Default: --folder.
  --start-index <number>        First variable index. Default: 1.
  --decimals <number>           Hue decimal places. Default: 1.
  --no-corrections              Disable dark/light contrast corrections.
  --help                        Show this help text.

Notes:
  The default setup rotates hue from red to red.
  Saturation and lightness stay mostly static.
  Dark mode brightens the cool blue/purple range.
  Light mode darkens the yellow/green range.
`.trim();

function fail(message: string): never {
    console.error(`Error: ${message}`);
    console.error('');
    console.error(HELP_TEXT);
    process.exit(1);
}

function clamp(value: number, min: number, max: number): number {
    if (Number.isNaN(value)) {
        throw new Error('Value must not be NaN.');
    }

    return Math.min(Math.max(value, min), max);
}

function round(value: number, decimals: number): number {
    if (!Number.isInteger(decimals) || decimals < 0) {
        throw new Error('decimals must be a non-negative integer.');
    }

    const factor = 10 ** decimals;
    return Math.round(value * factor) / factor;
}

function parseNumber(value: string, optionName: string): number {
    const parsed = Number(value);

    if (!Number.isFinite(parsed)) {
        fail(`${optionName} must be a finite number.`);
    }

    return parsed;
}

function parseInteger(value: string, optionName: string): number {
    const parsed = Number(value);

    if (!Number.isInteger(parsed)) {
        fail(`${optionName} must be an integer.`);
    }

    return parsed;
}

function parseThemeMode(value: string): ThemeMode {
    if (value === 'dark' || value === 'light' || value === 'none') {
        return value;
    }

    fail('--mode must be dark, light, or none.');
}

function parseRotateChannel(value: string): HslChannel {
    if (value === 'hue' || value === 'saturation' || value === 'lightness') {
        return value;
    }

    fail('--rotate-channel must be hue, saturation, or lightness.');
}

function readRequiredValue(args: string[], index: number, optionName: string): string {
    const value = args[index + 1];

    if (value === undefined || value.startsWith('--')) {
        fail(`Missing value for ${optionName}.`);
    }

    return value;
}

function padVariableIndex(index: number, count: number): string {
    const width = Math.max(2, String(count).length);
    return String(index).padStart(width, '0');
}

function isRatioInZone(ratio: number, zone: CorrectionZone): boolean {
    if (zone.fromRatio === zone.toRatio) {
        return ratio === zone.fromRatio;
    }

    return ratio >= zone.fromRatio && ratio <= zone.toRatio;
}

function applyCorrections(
    ratio: number,
    saturation: number,
    lightness: number,
    mode: ThemeMode,
    options: RainbowColourOptions,
): { saturation: number; lightness: number } {
    if (!options.corrections || mode === 'none') {
        return { saturation, lightness };
    }

    const zones = mode === 'dark' ? options.darkCorrections : options.lightCorrections;

    return zones.reduce(
        (current, zone) => {
            if (!isRatioInZone(ratio, zone)) {
                return current;
            }

            return {
                saturation: current.saturation + zone.saturationOffset,
                lightness: current.lightness + zone.lightnessOffset,
            };
        },
        { saturation, lightness },
    );
}

function interpolate(start: number, end: number, ratio: number): number {
    return start + ratio * (end - start);
}

function toHslString(
    hue: number,
    saturation: number,
    lightness: number,
    decimals: number,
): string {
    return `hsl(${round(hue, decimals)} ${round(clamp(saturation, 0, 100), decimals)}% ${round(
        clamp(lightness, 0, 100),
        decimals,
    )}%)`;
}

export function generateRainbowCssVariables(
    userOptions: Partial<RainbowColourOptions> = {},
): string {
    const options: RainbowColourOptions = {
        ...DEFAULT_CONFIG,
        ...userOptions,
        darkCorrections: userOptions.darkCorrections ?? DEFAULT_CONFIG.darkCorrections,
        lightCorrections: userOptions.lightCorrections ?? DEFAULT_CONFIG.lightCorrections,
    };

    if (!Number.isInteger(options.count) || options.count < 2) {
        throw new Error('count must be an integer greater than or equal to 2.');
    }

    if (!Number.isInteger(options.startIndex) || options.startIndex < 0) {
        throw new Error('startIndex must be a non-negative integer.');
    }

    if (!Number.isInteger(options.decimals) || options.decimals < 0) {
        throw new Error('decimals must be a non-negative integer.');
    }

    const lines = Array.from({ length: options.count }, (_, arrayIndex) => {
        const ratio = arrayIndex / (options.count - 1);

        let hue = options.startHue;
        let saturation = options.saturation;
        let lightness = options.lightness;

        if (options.rotateChannel === 'hue') {
            hue = interpolate(options.startHue, options.endHue, ratio);
        }

        if (options.rotateChannel === 'saturation') {
            saturation = interpolate(options.saturation, options.endHue, ratio);
        }

        if (options.rotateChannel === 'lightness') {
            lightness = interpolate(options.lightness, options.endHue, ratio);
        }

        const corrected = applyCorrections(
            ratio,
            saturation,
            lightness,
            options.mode,
            options,
        );

        const variableIndex = options.startIndex + arrayIndex;
        const slot = padVariableIndex(variableIndex, options.startIndex + options.count - 1);

        return `${options.variablePrefix}-${slot}: ${toHslString(
            hue,
            corrected.saturation,
            corrected.lightness,
            options.decimals,
        )};`;
    });

    return lines.join('\n');
}

function parseCliArgs(args: string[]): CliConfig {
    const config: CliConfig = { ...DEFAULT_CONFIG };

    if (args.includes('--help')) {
        console.log(HELP_TEXT);
        process.exit(0);
    }

    for (let index = 0; index < args.length; index += 1) {
        const arg = args[index];

        switch (arg) {
            case '--count': {
                const value = readRequiredValue(args, index, '--count');
                config.count = parseInteger(value, '--count');

                if (config.count < 2) {
                    fail('--count must be greater than or equal to 2.');
                }

                index += 1;
                break;
            }

            case '--mode': {
                const value = readRequiredValue(args, index, '--mode');
                config.mode = parseThemeMode(value);
                index += 1;
                break;
            }

            case '--rotate-channel': {
                const value = readRequiredValue(args, index, '--rotate-channel');
                config.rotateChannel = parseRotateChannel(value);
                index += 1;
                break;
            }

            case '--start-hue': {
                const value = readRequiredValue(args, index, '--start-hue');
                config.startHue = parseNumber(value, '--start-hue');
                index += 1;
                break;
            }

            case '--end-hue': {
                const value = readRequiredValue(args, index, '--end-hue');
                config.endHue = parseNumber(value, '--end-hue');
                index += 1;
                break;
            }

            case '--saturation': {
                const value = readRequiredValue(args, index, '--saturation');
                config.saturation = parseNumber(value, '--saturation');
                index += 1;
                break;
            }

            case '--lightness': {
                const value = readRequiredValue(args, index, '--lightness');
                config.lightness = parseNumber(value, '--lightness');
                index += 1;
                break;
            }

            case '--variable-prefix': {
                config.variablePrefix = readRequiredValue(args, index, '--variable-prefix');
                index += 1;
                break;
            }

            case '--start-index': {
                const value = readRequiredValue(args, index, '--start-index');
                config.startIndex = parseInteger(value, '--start-index');

                if (config.startIndex < 0) {
                    fail('--start-index must be greater than or equal to 0.');
                }

                index += 1;
                break;
            }

            case '--decimals': {
                const value = readRequiredValue(args, index, '--decimals');
                config.decimals = parseInteger(value, '--decimals');

                if (config.decimals < 0) {
                    fail('--decimals must be greater than or equal to 0.');
                }

                index += 1;
                break;
            }

            case '--no-corrections': {
                config.corrections = false;
                break;
            }

            default: {
                fail(`Unknown option: ${arg ?? '<empty>'}.`);
            }
        }
    }

    return config;
}

function isDirectRun(): boolean {
    const entry = process.argv[1];

    if (entry === undefined) {
        return false;
    }

    return import.meta.url === new URL(`file://${entry}`).href;
}

function main(): void {
    try {
        const config = parseCliArgs(process.argv.slice(2));
        const output = generateRainbowCssVariables(config);

        console.log(output);
    } catch (error: unknown) {
        const message = error instanceof Error ? error.message : String(error);
        fail(message);
    }
}

if (isDirectRun()) {
    main();
}
