#!/usr/bin/env -S node --experimental-strip-types

import { main } from "./src/cli.ts";

process.exitCode = await main();
