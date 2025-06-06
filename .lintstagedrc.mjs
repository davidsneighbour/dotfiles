// @see https://github.com/lint-staged/lint-staged
import { ESLint } from 'eslint'

const removeIgnoredFiles = async (/** @type {any[]} */ files) => {
  const eslint = new ESLint()
  const isIgnored = await Promise.all(
    files.map((/** @type {string} */ file) => {
      return eslint.isPathIgnored(file)
    })
  )
  const filteredFiles = files.filter((/** @type {any} */ _, /** @type {string | number} */ i) => !isIgnored[i])
  return filteredFiles.join(' ')
}

/**
 * @filename: .lintstagedrc.mjs
 * @type {import('lint-staged').Configuration}
 */
export default {
  // '*.{json,jsonc}': ['biome check --staged'],
  // '.github/workflows/**/*.y(a?)ml': [
  //   'zizmor --no-exit-codes',
  // ],
  'package-lock.json': [
    'lockfile-lint --path package-lock.json --validate-https --allowed-hosts npm',
  ],
  '*.{ts,tsx,(m|c)js,jsx}': async (/** @type {any} */ files) => {
    const filesToLint = await removeIgnoredFiles(files)
    return [
      `eslint --max-warnings=0 ${filesToLint}`,
      //'biome check --staged'
    ]
  },
  '*.yaml': ['yamllint -c .yamllint.yml'],
  // '*.{scss,css}': ['stylelint --fix', "prettier --write"],
  // '*.{png,jpeg,jpg,gif,svg}': [
  //   'imagemin-lint-staged' // @davidsneighbour/imagemin-lint-staged
  // ],
  // '!(CHANGELOG)**/*.{md,markdown}': [
  //   'markdownlint-cli2',
  //   'npm run lint:vale'
  // ],
  // '**/*.ts?(x)': () => [
  //   'tsc -p tsconfig.json --noEmit', "prettier --write"
  // ],
  // 'layouts/**/*.*': [
  //   './bin/hugo/refactor layouts'
  // ],
  // '**/*.*': [
  //   'npx secretlint'
  // ]
  '*.jsonnet': [
    'jsonnetfmt -i *.jsonnet',
  ],
}
