import type { Configuration } from 'nano-staged';

export default {
  '*': 'oxfmt --no-error-on-unmatched-pattern',
  '**/*.{js,ts,jsx,tsx}': 'oxlint',
  '**/*.css': 'stylelint --fix',
} as Configuration;
