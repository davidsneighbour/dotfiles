import { defineConfig } from 'cspell';

export default defineConfig({
  version: '0.2',
  language: 'en-GB',
  ignorePaths: ['./.vscode/cspell-dict-dotfiles.txt'],
  dictionaryDefinitions: [
    {
      name: 'custom',
      path: './.vscode/cspell-dict-dotfiles.txt',
      addWords: true,
    },
  ],
  dictionaries: ['custom'],
  words: [],
  ignoreWords: [],
  import: [],
});
