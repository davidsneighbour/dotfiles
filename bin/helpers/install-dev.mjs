#!/usr/bin/env node

import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import toml from 'toml';
import { intro, outro, isCancel, cancel, text, confirm, select, multiselect, spinner } from '@clack/prompts';
import shell from 'shelljs';

// Function to display help
function showHelp() {
  console.log(`
Usage: node runPrograms.mjs [options]

Options:
  --config <path>  Path to the TOML configuration file (default: ./install-dev.toml)
  --help           Show this help message and exit
  `);
  process.exit(0);
}

// Get the directory name of the current module
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Parse command-line arguments
const args = process.argv.slice(2);
let configPath = join(__dirname, 'install-dev.toml');
if (args.includes('--help')) {
  showHelp();
}
if (args.includes('--config')) {
  const configIndex = args.indexOf('--config');
  if (configIndex !== -1 && args[configIndex + 1]) {
    configPath = args[configIndex + 1];
  } else {
    console.error('Error: --config option requires a path argument.');
    process.exit(1);
  }
}

// Load and parse the TOML configuration file
let config;
try {
  const tomlContent = fs.readFileSync(configPath, 'utf8');
  config = toml.parse(tomlContent);
} catch (error) {
  console.error('Error reading or parsing the TOML file:', error.message);
  process.exit(1);
}

async function main() {
  intro('Install Dev Environment');

  // Prepare the selection options from the config
  const options = config.tool.map(function (tool, index) {
    return ({
      label: tool.label,
      value: tool.exec,
    });
  });

  // Display the multi-select prompt
  const selectedIndices = await multiselect({
    message: 'Select programs to run:',
    options,
  });

  if (isCancel(selectedIndices)) {
    cancel('Operation cancelled.');
    process.exit(0);
  }

  if (selectedIndices.length === 0) {
    outro('No programs selected.');
    process.exit(0);
  }

  // Confirm the selected programs
  const confirmRun = await confirm({
    message: 'Do you want to run the selected programs?',
  });

  if (!confirmRun) {
    outro('Operation cancelled.');
    process.exit(0);
  }

  // Run the selected programs
  const s = spinner();
  s.start('Executing');
  for (const command of selectedIndices) {
    if (shell.exec(command, { stdio: 'inherit' }).code !== 0) {
      console.error(`Error executing: ${command}`);
      process.exit(1);
    }
  }
  s.stop('Done');

  outro('All selected programs executed successfully.');
}

main().catch((error) => {
  console.error('An unexpected error occurred:', error.message);
  process.exit(1);
});
