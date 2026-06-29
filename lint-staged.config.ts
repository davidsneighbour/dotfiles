/**
 * @filename: .lintstagedrc.mjs
 * @type {import("lint-staged").Configuration}
 */
export default {
  '*.{json,jsonc}': ['biome check --write --staged'],
  '.github/workflows/**/*.y(a?)ml': ['zizmor --no-exit-codes --fix'],
  'package-lock.json': [
    'lockfile-lint --path package-lock.json --validate-https --allowed-hosts npm',
  ],
  '*.{ts,tsx,(m|c)js,jsx}': [
    'biome check --write --staged --no-errors-on-unmatched',
  ],
  '*.y(a?)ml': ['yamllint -c .yamllint.yml'],
  '*.{scss,css}': ['stylelint --fix'],
  '*.{png,jpeg,jpg,gif,svg}': ['sharp-lint-staged'],
  '!(CHANGELOG)**/*.{md,markdown}': [
    'markdownlint-cli2 --config node_modules/@dnbhq/markdownlint-config/.markdownlint-cli2.jsonc --no-globs',
  ],
  '**/*.ts?(x)': () => ['tsc-files --noEmit --pretty'],
  '**/*.*': ['secretlint --no-glob'],
  '*.jsonnet': ['jsonnetfmt -i *.jsonnet'],
};
