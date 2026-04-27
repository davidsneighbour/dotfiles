# Node Environment

Dotfiles set up a nvm environment that enables us to change the used node version on a per project (per folder) basis. The root of the project (which is linked to $HOME) contains a `.nvmrc` file that specifies `node` as required version which results in the latest version. Using `cd` will read an existing `.nvmrc` file and switch to the specified version. If no `cd` was used to open a terminal in a folder, use `cd .` to re-run the command and switch to the correct node version. Or "just" do `nvm use` like normal people would do.

## TypeScript

This repository assumes Node.js v25+ and uses direct execution of TypeScript files. Relative local imports in TypeScript files must use explicit `.ts` extensions.
