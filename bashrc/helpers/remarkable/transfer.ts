#!/usr/bin/env node

import { cp, mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { tmpdir } from "node:os";
import { basename, extname, join } from "node:path";

type SupportedExtension = "pdf" | "epub";
type TransferDirection = "up" | "down";
type Mode = "transfer" | "backup" | "raw-backup";

interface ParsedArguments {
    all: boolean;
    direction: TransferDirection;
    files: string[];
    id?: string;
    includeDeleted: boolean;
    mode: Mode;
    name?: string;
    outputDirectory: string;
    prune: boolean;
    restartToggle: boolean;
    safe: boolean;
    showHelp: boolean;
    verbose: boolean;
}

interface Config extends ParsedArguments {
    remarkableHost: string;
    remarkableXochitlDir: string;
    restartXochitl: boolean;
    restartXochitlDefault: boolean;
}

interface RemoteDocumentMetadata {
    deleted: boolean;
    type: string;
    visibleName: string;
}

interface RemoteDocument {
    deleted: boolean;
    extension: SupportedExtension;
    uuid: string;
    visibleName: string;
}

interface DownConfig {
    all: boolean;
    id?: string;
    includeDeleted: boolean;
    name?: string;
    outputDirectory: string;
    remarkableHost: string;
    remarkableXochitlDir: string;
    verbose: boolean;
}

interface RawBackupConfig {
    outputDirectory: string;
    prune: boolean;
    remarkableHost: string;
    remarkableXochitlDir: string;
    safe: boolean;
    verbose: boolean;
}

class CliError extends Error {
    public constructor(message: string) {
        super(message);
        this.name = "CliError";
    }
}

/**
 * Prints CLI usage and documentation.
 *
 * @param commandName - Current command name.
 */
function printHelp(commandName: string): void {
    console.log(`
Transfer documents to and from a reMarkable tablet.

Usage:
  ${commandName} --file ./document.pdf
  ${commandName} --up --file ./document.pdf --file ./book.epub
  ${commandName} --down --all --output-dir ./remarkable
  ${commandName} backup
  ${commandName} raw-backup
  ${commandName} raw-backup --safe
  ${commandName} raw-backup --safe --prune

Aliases:
  backup
    Same as: --down --all --output-dir ./remarkable

  raw-backup
    Uses rsync to copy the complete xochitl directory into ./remarkable-xochitl-backup.

Options:
  --up
    Transfer local PDF/EPUB files to the tablet.
    This is the default direction.

  --down
    Transfer PDF/EPUB files from the tablet to the local machine.

  --file <path>
    Local file to transfer up.
    Can be used multiple times.

  --all
    With --down, download all readable PDF/EPUB documents.

  --name <text>
    With --down, download documents whose visibleName contains the given text.

  --id <uuid>
    With --down, download one document by UUID.

  --output-dir <path>
    Local output directory for --down or raw-backup.
    Default for --down: ./remarkable-downloads
    Default for backup: ./remarkable
    Default for raw-backup: ./remarkable-xochitl-backup

  --include-deleted
    With --down, include documents marked as deleted in metadata.

  --restart, -r
    Toggle xochitl restart behaviour after upload.
    If RESTART_XOCHITL_DEFAULT=0, this enables restart.
    If RESTART_XOCHITL_DEFAULT=1, this disables restart.

  --safe
    With raw-backup, stop xochitl before rsync and start it afterwards.

  --prune
    With raw-backup, pass --delete to rsync.
    This makes the local backup mirror the remote directory.

  --verbose
    Print command execution details.

  --help, -h
    Show this help.

Environment variables:
  REMARKABLE_HOST
    SSH host alias for the tablet.
    Default: remarkable

  REMARKABLE_XOCHITL_DIR
    Remote xochitl document directory.
    Default: .local/share/remarkable/xochitl/

  RESTART_XOCHITL_DEFAULT
    Whether to restart xochitl after upload by default.
    Use 1 to enable, 0 to disable.
    Default: 0

Prerequisites:
  SSH access must be configured for the selected REMARKABLE_HOST.
  Upload and download use scp.
  Raw backup uses rsync.
`.trim());
}

/**
 * Parses a boolean environment variable.
 *
 * @param value - Raw environment variable value.
 * @param fallback - Fallback value if the variable is unset.
 * @returns Parsed boolean value.
 */
function parseBooleanEnv(value: string | undefined, fallback: boolean): boolean {
    if (value === undefined || value.trim() === "") {
        return fallback;
    }

    const normalised = value.trim().toLowerCase();

    if (normalised === "1" || normalised === "true") {
        return true;
    }

    if (normalised === "0" || normalised === "false") {
        return false;
    }

    throw new CliError(`Invalid boolean environment value: "${value}". Use 1, 0, true, or false.`);
}

/**
 * Reads the next CLI argument value.
 *
 * @param argv - Raw CLI arguments.
 * @param index - Current argument index.
 * @param optionName - Current option name.
 * @returns The next value.
 */
function readOptionValue(argv: string[], index: number, optionName: string): string {
    const value = argv[index + 1];

    if (value === undefined || value.startsWith("--")) {
        throw new CliError(`Missing value for ${optionName}.`);
    }

    return value;
}

/**
 * Parses CLI arguments.
 *
 * @param argv - Raw CLI arguments.
 * @returns Parsed arguments.
 */
function parseArguments(argv: string[]): ParsedArguments {
    const files: string[] = [];

    let all = false;
    let direction: TransferDirection = "up";
    let id: string | undefined;
    let includeDeleted = false;
    let mode: Mode = "transfer";
    let name: string | undefined;
    let outputDirectory = "./remarkable-downloads";
    let prune = false;
    let restartToggle = false;
    let safe = false;
    let showHelp = false;
    let verbose = false;

    for (let index = 0; index < argv.length; index += 1) {
        const argument = argv[index];

        if (argument === undefined) {
            throw new CliError("Unexpected missing CLI argument.");
        }

        if (argument === "backup") {
            direction = "down";
            mode = "backup";
            all = true;
            outputDirectory = "./remarkable";
            continue;
        }

        if (argument === "raw-backup") {
            direction = "down";
            mode = "raw-backup";
            outputDirectory = "./remarkable-xochitl-backup";
            continue;
        }

        if (argument === "--help" || argument === "-h") {
            showHelp = true;
            continue;
        }

        if (argument === "--up") {
            direction = "up";
            continue;
        }

        if (argument === "--down") {
            direction = "down";
            continue;
        }

        if (argument === "--file") {
            const filePath = readOptionValue(argv, index, "--file");
            files.push(filePath);
            index += 1;
            continue;
        }

        if (argument.startsWith("--file=")) {
            const filePath = argument.slice("--file=".length);

            if (filePath.trim() === "") {
                throw new CliError("Missing value for --file.");
            }

            files.push(filePath);
            continue;
        }

        if (argument === "--all") {
            all = true;
            continue;
        }

        if (argument === "--name") {
            name = readOptionValue(argv, index, "--name");
            index += 1;
            continue;
        }

        if (argument === "--id") {
            id = readOptionValue(argv, index, "--id");
            index += 1;
            continue;
        }

        if (argument === "--output-dir") {
            outputDirectory = readOptionValue(argv, index, "--output-dir");
            index += 1;
            continue;
        }

        if (argument === "--include-deleted") {
            includeDeleted = true;
            continue;
        }

        if (argument === "--restart" || argument === "-r") {
            restartToggle = true;
            continue;
        }

        if (argument === "--safe") {
            safe = true;
            continue;
        }

        if (argument === "--prune") {
            prune = true;
            continue;
        }

        if (argument === "--verbose") {
            verbose = true;
            continue;
        }

        if (argument.startsWith("-")) {
            throw new CliError(`Unknown option: ${argument}`);
        }

        files.push(argument);
    }

    return {
        all,
        direction,
        files,
        id,
        includeDeleted,
        mode,
        name,
        outputDirectory,
        prune,
        restartToggle,
        safe,
        showHelp,
        verbose,
    };
}

/**
 * Creates runtime configuration from CLI arguments and environment variables.
 *
 * @param argv - Raw CLI arguments.
 * @returns Runtime configuration or null when help should be printed.
 */
function createConfig(argv: string[]): Config | null {
    const parsed = parseArguments(argv);

    if (parsed.showHelp) {
        return null;
    }

    const restartXochitlDefault = parseBooleanEnv(process.env.RESTART_XOCHITL_DEFAULT, false);

    const config: Config = {
        ...parsed,
        remarkableHost: process.env.REMARKABLE_HOST ?? "remarkable",
        remarkableXochitlDir: process.env.REMARKABLE_XOCHITL_DIR ?? ".local/share/remarkable/xochitl/",
        restartXochitl: parsed.restartToggle ? !restartXochitlDefault : restartXochitlDefault,
        restartXochitlDefault,
    };

    validateConfig(config);

    return config;
}

/**
 * Validates runtime configuration.
 *
 * @param config - Runtime configuration.
 */
function validateConfig(config: Config): void {
    if (config.mode === "raw-backup") {
        return;
    }

    if (config.direction === "up" && config.files.length < 1) {
        throw new CliError("At least one file is required for upload.");
    }

    if (config.direction === "down") {
        const filters = [config.all, config.id !== undefined, config.name !== undefined].filter(Boolean);

        if (filters.length === 0) {
            throw new CliError("For --down, specify --all, --id <uuid>, or --name <text>.");
        }

        if (filters.length > 1) {
            throw new CliError("For --down, use only one of --all, --id, or --name.");
        }
    }
}

/**
 * Runs a command and rejects on non-zero exit code.
 *
 * @param command - Command to execute.
 * @param args - Command arguments.
 * @param verbose - Whether to print command details.
 */
async function runCommand(command: string, args: string[], verbose: boolean): Promise<void> {
    if (verbose) {
        console.log(`Running: ${command} ${args.join(" ")}`);
    }

    await new Promise<void>((resolve, reject) => {
        const child = spawn(command, args, {
            stdio: "inherit",
        });

        child.on("error", (error: Error) => {
            reject(new CliError(`Failed to run ${command}: ${error.message}`));
        });

        child.on("close", (code: number | null, signal: NodeJS.Signals | null) => {
            if (code === 0) {
                resolve();
                return;
            }

            if (signal !== null) {
                reject(new CliError(`${command} was terminated by signal ${signal}.`));
                return;
            }

            reject(new CliError(`${command} exited with code ${code ?? "unknown"}.`));
        });
    });
}

/**
 * Runs a command and captures stdout.
 *
 * @param command - Command to execute.
 * @param args - Command arguments.
 * @param verbose - Whether to print command details.
 * @returns Captured stdout.
 */
async function captureCommand(command: string, args: string[], verbose: boolean): Promise<string> {
    if (verbose) {
        console.log(`Running: ${command} ${args.join(" ")}`);
    }

    return await new Promise<string>((resolve, reject) => {
        let stdout = "";
        let stderr = "";

        const child = spawn(command, args, {
            stdio: ["ignore", "pipe", "pipe"],
        });

        child.stdout.setEncoding("utf8");
        child.stderr.setEncoding("utf8");

        child.stdout.on("data", (chunk: string) => {
            stdout += chunk;
        });

        child.stderr.on("data", (chunk: string) => {
            stderr += chunk;
        });

        child.on("error", (error: Error) => {
            reject(new CliError(`Failed to run ${command}: ${error.message}`));
        });

        child.on("close", (code: number | null, signal: NodeJS.Signals | null) => {
            if (code === 0) {
                resolve(stdout);
                return;
            }

            if (signal !== null) {
                reject(new CliError(`${command} was terminated by signal ${signal}.`));
                return;
            }

            reject(new CliError(`${command} exited with code ${code ?? "unknown"}: ${stderr.trim()}`));
        });
    });
}

/**
 * Returns a supported source file extension.
 *
 * @param filePath - Source file path.
 * @returns Supported extension.
 */
function getSupportedExtension(filePath: string): SupportedExtension {
    const extension = extname(filePath).replace(".", "").toLowerCase();

    if (extension === "pdf" || extension === "epub") {
        return extension;
    }

    throw new CliError(`Unknown extension: ${extension || "(none)"}, skipping ${filePath}`);
}

/**
 * Creates the metadata JSON expected by reMarkable.
 *
 * @param sourceFile - Source file path.
 * @param extension - Source file extension.
 * @returns Metadata JSON string.
 */
function createMetadata(sourceFile: string, extension: SupportedExtension): string {
    const visibleName = basename(sourceFile, `.${extension}`);

    return `${JSON.stringify(
        {
            deleted: false,
            lastModified: `${Math.floor(Date.now() / 1000)}000`,
            metadatamodified: false,
            modified: false,
            parent: "",
            pinned: false,
            synced: false,
            type: "DocumentType",
            version: 1,
            visibleName,
        },
        null,
        2,
    )}\n`;
}

/**
 * Creates the content JSON expected by reMarkable.
 *
 * @param extension - Source file extension.
 * @returns Content JSON string.
 */
function createContent(extension: SupportedExtension): string {
    if (extension === "epub") {
        return `${JSON.stringify(
            {
                fileType: "epub",
            },
            null,
            2,
        )}\n`;
    }

    return `${JSON.stringify(
        {
            extraMetadata: {},
            fileType: "pdf",
            fontName: "",
            lastOpenedPage: 0,
            lineHeight: -1,
            margins: 100,
            pageCount: 1,
            textScale: 1,
            transform: {
                m11: 1,
                m12: 1,
                m13: 1,
                m21: 1,
                m22: 1,
                m23: 1,
                m31: 1,
                m32: 1,
                m33: 1,
            },
        },
        null,
        2,
    )}\n`;
}

/**
 * Prepares one document in the temporary upload directory.
 *
 * @param sourceFile - Source file path.
 * @param workDirectory - Temporary work directory.
 * @returns Generated reMarkable document UUID.
 */
async function prepareUploadDocument(sourceFile: string, workDirectory: string): Promise<string> {
    const uuid = randomUUID().toLowerCase();
    const extension = getSupportedExtension(sourceFile);

    await cp(sourceFile, join(workDirectory, `${uuid}.${extension}`));
    await writeFile(join(workDirectory, `${uuid}.metadata`), createMetadata(sourceFile, extension), "utf8");
    await writeFile(join(workDirectory, `${uuid}.content`), createContent(extension), "utf8");

    if (extension === "pdf") {
        await mkdir(join(workDirectory, `${uuid}.cache`));
        await mkdir(join(workDirectory, `${uuid}.highlights`));
        await mkdir(join(workDirectory, `${uuid}.thumbnails`));
    }

    return uuid;
}

/**
 * Removes and recreates the temporary work directory.
 *
 * @param workDirectory - Temporary work directory.
 */
async function clearWorkDirectory(workDirectory: string): Promise<void> {
    await rm(workDirectory, {
        force: true,
        recursive: true,
    });

    await mkdir(workDirectory, {
        recursive: true,
    });
}

/**
 * Transfers one local document to the reMarkable tablet.
 *
 * @param sourceFile - Source file path.
 * @param workDirectory - Temporary work directory.
 * @param config - Runtime configuration.
 */
async function uploadDocument(sourceFile: string, workDirectory: string, config: Config): Promise<void> {
    try {
        const uuid = await prepareUploadDocument(sourceFile, workDirectory);
        const targetDirectory = `${config.remarkableHost}:${config.remarkableXochitlDir}`;

        console.log(`Transferring ${sourceFile} as ${uuid}`);
        await runCommand("scp", ["-r", `${workDirectory}/.`, targetDirectory], config.verbose);
    } catch (error: unknown) {
        if (error instanceof CliError) {
            console.error(error.message);
            return;
        }

        if (error instanceof Error) {
            console.error(`Failed to transfer ${sourceFile}: ${error.message}`);
            return;
        }

        console.error(`Failed to transfer ${sourceFile}: Unknown error.`);
    } finally {
        await clearWorkDirectory(workDirectory);
    }
}

/**
 * Transfers all selected local documents to the reMarkable tablet.
 *
 * @param config - Runtime configuration.
 */
async function uploadToRemarkable(config: Config): Promise<void> {
    let workDirectory: string | undefined;

    try {
        workDirectory = await mkdtemp(join(tmpdir(), "remarkable-transfer-"));

        for (const file of config.files) {
            await uploadDocument(file, workDirectory, config);
        }

        if (config.restartXochitl) {
            console.log("Restarting Xochitl...");
            await runCommand("ssh", [config.remarkableHost, "systemctl restart xochitl"], config.verbose);
            console.log("Done.");
        }
    } finally {
        if (workDirectory !== undefined) {
            await rm(workDirectory, {
                force: true,
                recursive: true,
            });
        }
    }
}

/**
 * Quotes a string for POSIX shell usage.
 *
 * @param value - Raw value.
 * @returns Shell-quoted value.
 */
function shellQuote(value: string): string {
    return `'${value.replaceAll("'", "'\\''")}'`;
}

/**
 * Checks if a value is a plain object.
 *
 * @param value - Value to check.
 * @returns Whether the value is a plain object.
 */
function isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * Parses and validates a remote metadata JSON file.
 *
 * @param rawJson - Raw metadata JSON.
 * @param uuid - Document UUID.
 * @returns Parsed remote metadata.
 */
function parseRemoteMetadata(rawJson: string, uuid: string): RemoteDocumentMetadata {
    let parsed: unknown;

    try {
        parsed = JSON.parse(rawJson);
    } catch (error: unknown) {
        if (error instanceof Error) {
            throw new CliError(`Could not parse metadata for ${uuid}: ${error.message}`);
        }

        throw new CliError(`Could not parse metadata for ${uuid}: Unknown error.`);
    }

    if (!isRecord(parsed)) {
        throw new CliError(`Invalid metadata object for ${uuid}.`);
    }

    const deleted = typeof parsed.deleted === "boolean" ? parsed.deleted : false;
    const type = typeof parsed.type === "string" ? parsed.type : "";
    const visibleName = typeof parsed.visibleName === "string" && parsed.visibleName.trim() !== ""
        ? parsed.visibleName
        : uuid;

    return {
        deleted,
        type,
        visibleName,
    };
}

/**
 * Converts a visible document name into a safe local filename.
 *
 * @param value - Raw visibleName value.
 * @returns Safe filename.
 */
function sanitiseFileName(value: string): string {
    const cleaned = value
        .normalize("NFKD")
        .replace(/[^\p{L}\p{N}._ -]/gu, "_")
        .replace(/\s+/gu, " ")
        .replace(/_+/gu, "_")
        .trim();

    if (cleaned === "" || cleaned === "." || cleaned === "..") {
        return "remarkable-document";
    }

    return cleaned;
}

/**
 * Checks whether a remote file exists inside the xochitl directory.
 *
 * @param config - Download configuration.
 * @param remoteFileName - Remote filename.
 * @returns Whether the remote file exists.
 */
async function remoteFileExists(config: DownConfig, remoteFileName: string): Promise<boolean> {
    const remotePath = `${config.remarkableXochitlDir.replace(/\/$/u, "")}/${remoteFileName}`;

    try {
        await captureCommand("ssh", [config.remarkableHost, "test", "-f", remotePath], config.verbose);
        return true;
    } catch (error: unknown) {
        if (config.verbose) {
            const message = error instanceof Error ? error.message : "Unknown error";
            console.log(`Remote file missing or inaccessible: ${remotePath}. ${message}`);
        }

        return false;
    }
}

/**
 * Lists remote documents that have a directly downloadable PDF or EPUB source file.
 *
 * @param config - Download configuration.
 * @returns Downloadable remote documents.
 */
async function listDownloadableRemoteDocuments(config: DownConfig): Promise<RemoteDocument[]> {
    const remoteDirectory = config.remarkableXochitlDir.replace(/\/$/u, "");

    const metadataFilesRaw = await captureCommand(
        "ssh",
        [
            config.remarkableHost,
            "sh",
            "-lc",
            `cd ${shellQuote(remoteDirectory)} && find . -maxdepth 1 -type f -name '*.metadata' -printf '%f\\n'`,
        ],
        config.verbose,
    );

    const metadataFiles = metadataFilesRaw
        .split("\n")
        .map((line) => line.trim())
        .filter((line) => line !== "");

    const documents: RemoteDocument[] = [];

    for (const metadataFile of metadataFiles) {
        const uuid = metadataFile.replace(/\.metadata$/u, "");
        const rawJson = await captureCommand(
            "ssh",
            [config.remarkableHost, "cat", `${remoteDirectory}/${metadataFile}`],
            config.verbose,
        );

        const metadata = parseRemoteMetadata(rawJson, uuid);

        if (metadata.type !== "DocumentType") {
            continue;
        }

        if (metadata.deleted && !config.includeDeleted) {
            continue;
        }

        let extension: SupportedExtension | undefined;

        if (await remoteFileExists(config, `${uuid}.pdf`)) {
            extension = "pdf";
        } else if (await remoteFileExists(config, `${uuid}.epub`)) {
            extension = "epub";
        }

        if (extension === undefined) {
            continue;
        }

        documents.push({
            deleted: metadata.deleted,
            extension,
            uuid,
            visibleName: metadata.visibleName,
        });
    }

    return documents;
}

/**
 * Filters remote documents according to download options.
 *
 * @param documents - Available remote documents.
 * @param config - Download configuration.
 * @returns Filtered documents.
 */
function filterRemoteDocuments(documents: RemoteDocument[], config: DownConfig): RemoteDocument[] {
    if (config.id !== undefined) {
        return documents.filter((document) => document.uuid === config.id);
    }

    if (config.name !== undefined) {
        const needle = config.name.toLowerCase();

        return documents.filter((document) => document.visibleName.toLowerCase().includes(needle));
    }

    if (config.all) {
        return documents;
    }

    throw new CliError("For --down, specify --all, --id <uuid>, or --name <text>.");
}

/**
 * Sorts remote documents for deterministic output.
 *
 * @param documents - Remote documents.
 * @returns Sorted documents.
 */
function sortRemoteDocuments(documents: RemoteDocument[]): RemoteDocument[] {
    return [...documents].sort((left, right) => {
        const byName = left.visibleName.localeCompare(right.visibleName);

        if (byName !== 0) {
            return byName;
        }

        return left.uuid.localeCompare(right.uuid);
    });
}

/**
 * Builds a collision-safe local output path.
 *
 * @param outputDirectory - Local output directory.
 * @param document - Remote document.
 * @param usedNames - Already selected filenames.
 * @returns Local output path.
 */
function buildOutputPath(outputDirectory: string, document: RemoteDocument, usedNames: Set<string>): string {
    const baseName = sanitiseFileName(document.visibleName);
    let candidate = `${baseName}.${document.extension}`;
    let counter = 2;

    while (usedNames.has(candidate)) {
        candidate = `${baseName} (${counter}).${document.extension}`;
        counter += 1;
    }

    usedNames.add(candidate);

    return join(outputDirectory, candidate);
}

/**
 * Downloads selected PDF/EPUB documents from the reMarkable tablet.
 *
 * @param config - Download configuration.
 */
async function downloadFromRemarkable(config: DownConfig): Promise<void> {
    await mkdir(config.outputDirectory, {
        recursive: true,
    });

    const availableDocuments = await listDownloadableRemoteDocuments(config);
    const selectedDocuments = sortRemoteDocuments(filterRemoteDocuments(availableDocuments, config));

    if (selectedDocuments.length === 0) {
        console.log("No matching downloadable PDF or EPUB documents found.");
        return;
    }

    const usedNames = new Set<string>();

    for (const document of selectedDocuments) {
        const remoteDirectory = config.remarkableXochitlDir.replace(/\/$/u, "");
        const remoteFile = `${config.remarkableHost}:${remoteDirectory}/${document.uuid}.${document.extension}`;
        const outputPath = buildOutputPath(config.outputDirectory, document, usedNames);

        console.log(`Downloading ${document.visibleName} (${document.uuid}) to ${outputPath}`);
        await runCommand("scp", [remoteFile, outputPath], config.verbose);
    }
}

/**
 * Creates a raw rsync backup of the complete xochitl directory.
 *
 * This is a UUID-based storage backup, not a human-readable export.
 *
 * @param config - Raw backup configuration.
 */
async function rawBackupFromRemarkable(config: RawBackupConfig): Promise<void> {
    await mkdir(config.outputDirectory, {
        recursive: true,
    });

    if (config.safe) {
        console.log("Stopping xochitl...");
        await runCommand("ssh", [config.remarkableHost, "systemctl stop xochitl"], config.verbose);
    }

    try {
        const remoteSource = `${config.remarkableHost}:${config.remarkableXochitlDir.replace(/\/$/u, "")}/`;
        const args = ["-a", "--info=progress2"];

        if (config.prune) {
            args.push("--delete");
        }

        args.push(remoteSource, `${config.outputDirectory.replace(/\/$/u, "")}/`);

        console.log(`Backing up raw xochitl files to ${config.outputDirectory}`);
        await runCommand("rsync", args, config.verbose);
    } finally {
        if (config.safe) {
            console.log("Starting xochitl...");
            await runCommand("ssh", [config.remarkableHost, "systemctl start xochitl"], config.verbose);
        }
    }
}

/**
 * Runs the selected operation.
 *
 * @param config - Runtime configuration.
 */
async function run(config: Config): Promise<void> {
    if (config.mode === "raw-backup") {
        await rawBackupFromRemarkable({
            outputDirectory: config.outputDirectory,
            prune: config.prune,
            remarkableHost: config.remarkableHost,
            remarkableXochitlDir: config.remarkableXochitlDir,
            safe: config.safe,
            verbose: config.verbose,
        });

        return;
    }

    if (config.direction === "down") {
        await downloadFromRemarkable({
            all: config.all,
            id: config.id,
            includeDeleted: config.includeDeleted,
            name: config.name,
            outputDirectory: config.outputDirectory,
            remarkableHost: config.remarkableHost,
            remarkableXochitlDir: config.remarkableXochitlDir,
            verbose: config.verbose,
        });

        return;
    }

    await uploadToRemarkable(config);
}

/**
 * Main program entry point.
 */
async function main(): Promise<void> {
    const commandName = basename(process.argv[1] ?? "transfer-remarkable");

    if (process.argv.length <= 2) {
        printHelp(commandName);
        process.exitCode = 1;
        return;
    }

    const config = createConfig(process.argv.slice(2));

    if (config === null) {
        printHelp(commandName);
        return;
    }

    await run(config);
}

main().catch((error: unknown) => {
    const commandName = basename(process.argv[1] ?? "transfer-remarkable");

    if (error instanceof CliError) {
        console.error(`Error: ${error.message}`);
        console.error("");
        printHelp(commandName);
        process.exitCode = 1;
        return;
    }

    if (error instanceof Error) {
        console.error(`Unexpected error: ${error.message}`);
        process.exitCode = 1;
        return;
    }

    console.error("Unexpected unknown error.");
    process.exitCode = 1;
});