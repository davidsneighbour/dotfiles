import * as vscode from "vscode";

type IncrementType = "major" | "minor" | "patch";

type PackageJson = {
  readonly version?: unknown;
};

type ParsedSemver = {
  readonly major: number;
  readonly minor: number;
  readonly patch: number;
};

function isPackageJson(value: unknown): value is PackageJson {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function getErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }

  return String(error);
}

function getWorkspaceFolderForActiveEditor(): vscode.WorkspaceFolder | undefined {
  const editor = vscode.window.activeTextEditor;

  if (editor === undefined) {
    return vscode.workspace.workspaceFolders?.[0];
  }

  const workspaceFolder = vscode.workspace.getWorkspaceFolder(editor.document.uri);

  if (workspaceFolder !== undefined) {
    return workspaceFolder;
  }

  return vscode.workspace.workspaceFolders?.[0];
}

async function readPackageJson(workspaceFolder: vscode.WorkspaceFolder): Promise<PackageJson> {
  const packageJsonUri = vscode.Uri.joinPath(workspaceFolder.uri, "package.json");

  let rawPackageJson: Uint8Array;

  try {
    rawPackageJson = await vscode.workspace.fs.readFile(packageJsonUri);
  } catch (error: unknown) {
    throw new Error(
      `Could not read package.json at ${packageJsonUri.fsPath}: ${getErrorMessage(error)}`
    );
  }

  const packageJsonText = new TextDecoder("utf-8").decode(rawPackageJson);

  let parsedPackageJson: unknown;

  try {
    parsedPackageJson = JSON.parse(packageJsonText);
  } catch (error: unknown) {
    throw new Error(
      `Could not parse package.json at ${packageJsonUri.fsPath}: ${getErrorMessage(error)}`
    );
  }

  if (!isPackageJson(parsedPackageJson)) {
    throw new Error(`package.json at ${packageJsonUri.fsPath} is not a JSON object.`);
  }

  return parsedPackageJson;
}

async function getWorkspacePackageVersion(): Promise<string> {
  const workspaceFolder = getWorkspaceFolderForActiveEditor();

  if (workspaceFolder === undefined) {
    throw new Error("No workspace folder found.");
  }

  const packageJson = await readPackageJson(workspaceFolder);

  if (typeof packageJson.version !== "string") {
    throw new Error(
      `Missing or invalid "version" field in package.json for workspace "${workspaceFolder.name}".`
    );
  }

  const version = packageJson.version.trim();

  if (version.length === 0) {
    throw new Error(
      `Empty "version" field in package.json for workspace "${workspaceFolder.name}".`
    );
  }

  return version;
}

/**
 * Parses a simple SemVer version string.
 *
 * Supported:
 * - 1.2.3
 * - v1.2.3
 *
 * Not supported intentionally:
 * - 1.2
 * - 1.2.3-beta.1
 * - 1.2.3+build.1
 *
 * @param version - The version string from package.json.
 * @returns Parsed major, minor, and patch parts.
 */
function parseSemver(version: string): ParsedSemver {
  const match = /^v?(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*)$/.exec(
    version
  );

  if (match?.groups === undefined) {
    throw new Error(
      `Unsupported package version "${version}". Expected a simple SemVer version like "1.2.3".`
    );
  }

  const major = Number.parseInt(match.groups['major'] ?? "", 10);
  const minor = Number.parseInt(match.groups['minor'] ?? "", 10);
  const patch = Number.parseInt(match.groups['patch'] ?? "", 10);

  if (!Number.isSafeInteger(major) || !Number.isSafeInteger(minor) || !Number.isSafeInteger(patch)) {
    throw new Error(`Invalid package version "${version}". Version parts must be safe integers.`);
  }

  return {
    major,
    minor,
    patch
  };
}

/**
 * Increments a parsed SemVer version.
 *
 * @param version - The parsed SemVer object.
 * @param incrementType - The increment type to apply.
 * @returns The incremented version string.
 */
function incrementSemver(version: ParsedSemver, incrementType: IncrementType): string {
  switch (incrementType) {
    case "major":
      return `${version.major + 1}.0.0`;

    case "minor":
      return `${version.major}.${version.minor + 1}.0`;

    case "patch":
      return `${version.major}.${version.minor}.${version.patch + 1}`;

    default: {
      const exhaustiveCheck: never = incrementType;

      throw new Error(`Unhandled increment type: ${exhaustiveCheck}`);
    }
  }
}

/**
 * Reads the workspace package version and returns the next version.
 *
 * @param incrementType - The increment type to apply.
 * @returns The next package version.
 */
async function getNextWorkspacePackageVersion(incrementType: IncrementType): Promise<string> {
  const currentVersion = await getWorkspacePackageVersion();
  const parsedVersion = parseSemver(currentVersion);

  return incrementSemver(parsedVersion, incrementType);
}

async function insertTextAtSelections(text: string): Promise<void> {
  const editor = vscode.window.activeTextEditor;

  if (editor === undefined) {
    throw new Error("No active editor found.");
  }

  const didEdit = await editor.edit((editBuilder) => {
    for (const selection of editor.selections) {
      editBuilder.replace(selection, text);
    }
  });

  if (!didEdit) {
    throw new Error("VS Code rejected the editor edit.");
  }
}

/**
 * Registers a command that inserts an incremented package version.
 *
 * @param context - The VS Code extension context.
 * @param commandId - The command identifier.
 * @param incrementType - The increment type to apply.
 */
function registerInsertNextVersionCommand(
  context: vscode.ExtensionContext,
  commandId: string,
  incrementType: IncrementType
): void {
  const disposable = vscode.commands.registerCommand(commandId, async () => {
    try {
      const nextVersion = await getNextWorkspacePackageVersion(incrementType);

      await insertTextAtSelections(nextVersion);
    } catch (error: unknown) {
      vscode.window.showErrorMessage(
        `Package version insert failed: ${getErrorMessage(error)}`
      );
    }
  });

  context.subscriptions.push(disposable);
}

export function activate(context: vscode.ExtensionContext): void {
  registerInsertNextVersionCommand(
    context,
    "dnb-dotfiles-tools.insertNextVersion",
    "minor"
  );

  registerInsertNextVersionCommand(
    context,
    "dnb-dotfiles-tools.insertNextMajorVersion",
    "major"
  );

  registerInsertNextVersionCommand(
    context,
    "dnb-dotfiles-tools.insertNextMinorVersion",
    "minor"
  );

  registerInsertNextVersionCommand(
    context,
    "dnb-dotfiles-tools.insertNextPatchVersion",
    "patch"
  );
}

export function deactivate(): void {
  // No cleanup required.
}