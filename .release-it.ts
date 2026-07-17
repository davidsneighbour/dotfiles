import { createReleaseConfig } from '@dnbhq/release-config';
import type { Config } from 'release-it';

const config: Config = createReleaseConfig({
  scopes: {
    minorTypes: ['feat', 'prompts', 'instructions', 'skills'],
    patchTypes: [
      'fix',
      'perf',
      'refactor',
      'docs',
      'style',
      'test',
      'build',
      'ci',
      'chore',
      'config',
      'ai',
    ],
    minorExclusionSubscopes: {
      feat: ['fix'],
      prompts: ['fix'],
      instructions: ['fix'],
      skills: ['fix'],
    },
  },
  overrides: {
    git: {
      requireCleanWorkingDir: false,
      commitArgs: ['--signoff', '--no-verify'],
    },
    hooks: {
      'before:init': [
        'git update-index -q --refresh',
        'git diff-index --quiet --ignore-submodules=dirty HEAD --',
      ],
      'before:git:release': [
        'if [ -f CITATION.cff ]; then sed -Ei "s/^version: .*/version: ${version}/" CITATION.cff; git add CITATION.cff; fi',
      ],
      'after:release': [
        'if [ -f bashrc/lib/45-workspace/dnb-gitmarker.bash ]; then source bashrc/lib/45-workspace/dnb-gitmarker.bash; if declare -F gitmark-set >/dev/null 2>&1; then gitmark-set; else echo "gitmark-set function missing after sourcing bashrc/lib/45-workspace/dnb-gitmarker.bash; skipping."; fi; else echo "bashrc/lib/45-workspace/dnb-gitmarker.bash not found; skipping gitmark-set."; fi',
      ],
    },
  },
});

export default config;
