/**
 * Ensures the current Node.js version satisfies a minimum major version.
 *
 * @param requiredMajor - Minimum required Node.js major version.
 */
export function ensureNodeVersion(requiredMajor: number): void {
    const raw = process.versions.node;
    const major = Number.parseInt(raw.split('.')[0] ?? '', 10);

    if (!Number.isInteger(major)) {
        console.error(`Unable to parse Node.js version: ${raw}`);
        process.exit(1);
    }

    if (major < requiredMajor) {
        console.error(`Node.js >= ${requiredMajor} required, current: ${raw}`);
        process.exit(1);
    }
}