import type { Config } from 'release-it';

const config = {
  npm: {
    publish: false,
  },
  git: {
    requireBranch: 'main',
    requireCleanWorkingDir: false, // we are doing that in hooks and ignore dirty submodules
    commit: true,
    commitArgs: ['--signoff', '--no-verify'],
    commitMessage: 'chore(release): v${version}',
    tag: true,
    tagName: 'v${version}',
    push: true,
    pushArgs: ['--follow-tags'],
  },
  hooks: {
    'before:init': [
      'git update-index -q --refresh',
      'git diff-index --quiet --ignore-submodules=dirty HEAD --',
    ],
  },
  github: {
    release: true,
    releaseName: 'v${version}',
    skipChecks: true,
    tokenRef: 'GITHUB_TOKEN_DEV',
  },
  plugins: {
    '@release-it/conventional-changelog': {
      infile: 'CHANGELOG.md',
      preset: {
        name: 'conventionalcommits',
        types: [
          { type: 'feat', section: 'Features' },
          { type: 'fix', section: 'Bug Fixes' },
          { type: 'config', section: 'Configuration' },
          { type: 'docs', section: 'Documentation' },
          { type: 'build', section: 'Build' },
          { type: 'chore', section: 'Chore' },
        ],
      },
      whatBump(commits: Array<{ type?: string; notes?: unknown[] }>) {
        let level: 2 | 1 | 0 | null = null;

        for (const commit of commits) {
          const notes = Array.isArray(commit.notes) ? commit.notes : [];
          const type = typeof commit.type === 'string' ? commit.type : '';

          if (notes.length > 0) {
            return {
              level: 0,
              reason: 'There are BREAKING CHANGES.',
            };
          }

          if (type === 'feat') {
            level = 1;
            continue;
          }

          if (
            level === null &&
            [
              'fix',
              'config',
              'docs',
              'build',
              'chore',
            ].includes(type)
          ) {
            level = 2;
          }
        }

        if (level === null) {
          return false;
        }

        return {
          level,
          reason:
            level === 1
              ? 'There are feat/content commits.'
              : 'There are patch-level changes.',
        };
      },
    },
  },
} satisfies Config;

export default config;
