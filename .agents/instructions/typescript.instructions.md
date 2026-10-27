---
applyTo: "**/*.ts,**/*.tsx,**/*.js,**/*.jsx,**/*.mjs,**/*.mts,**/package.json,**/tsconfig*.json"
---

<!-- markdownlint-disable-next-line dnb-title-case-style -->
# Node.js and TypeScript

When Node.js is used:

* ESM only
* No `require`
* No `any` typing
* Use strict TypeScript
* Standalone repository TypeScript tooling must run directly via `node script.ts`. Frontend modules follow their existing bundler and TypeScript configuration.

## Error handling

* No empty `catch` blocks
* Errors must be logged
* Failures must be explicit
