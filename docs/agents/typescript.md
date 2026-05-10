# TypeScript agent rules

These rules record the TypeScript diagnostics found while making `npx tsc --noEmit` clean and are mandatory for future AI-agent changes to TypeScript and checked JavaScript in this repository.

## Required check

Run the repository typecheck before handing work back:

```bash
npx tsc --noEmit
```

A successful run may still print npm environment warnings that are outside the TypeScript compiler. Do not treat those warnings as permission to ignore TypeScript diagnostics.

## Rules that prevent the collected diagnostics

### Use explicit types at TypeScript boundaries

Do not rely on JavaScript-style JSDoc comments to type parameters in `.ts` files. TypeScript does not use those comments as parameter annotations for strict `.ts` checking.

For every function in a `.ts` file:

- annotate parameters directly;
- annotate return types for exported functions, CLI entry points, async helpers, parsers, and type guards;
- type promise values explicitly when TypeScript cannot infer the resolved value.

This prevents `TS7006` implicit `any`, `TS7019` implicit `any[]` rest parameters, and confusing downstream `unknown` diagnostics.

### Do not introduce `any`

Repository code must not use `any` as a shortcut for dynamic data. Use `unknown`, `Record<string, unknown>`, or a purpose-specific type plus a runtime guard.

When parsing JSON or consuming third-party API payloads:

- keep the parsed value as `unknown`;
- validate it with local type guards before reading properties;
- narrow arrays with type-predicate filters, for example `.filter((tag): tag is string => ...)`.

### Respect `noPropertyAccessFromIndexSignature`

Values whose types come from index signatures must be accessed with bracket notation, not dot notation.

Use:

```ts
process.env["TOKEN_NAME"];
record["propertyName"];
```

Do not use:

```ts
process.env.TOKEN_NAME;
record.propertyName;
```

This prevents `TS4111` diagnostics for environment variables and dynamic records.

### Respect `noUncheckedIndexedAccess`

Every array or index lookup can be `undefined`. Guard the value before using it.

Use:

```ts
const first = files[0];
if (first === undefined) {
  return;
}
```

Do not assume that previous length checks, loops, or `matches[0]` access will always be understood by the compiler. When the indexed value is required, make the guard explicit and throw an actionable error if continuing would be unsafe.

This prevents `TS2532`, `TS2538`, and `TS18048` diagnostics.

### Respect `exactOptionalPropertyTypes`

Optional properties must either be omitted or contain a value of the declared type. Do not assign `undefined` to optional properties unless the property type explicitly includes `undefined`.

Use:

```ts
const config: DownConfig = { outputDirectory };
if (id !== undefined) {
  config.id = id;
}
```

Do not use:

```ts
const config: DownConfig = { outputDirectory, id };
```

This prevents `TS2375` and `TS2379` diagnostics.

### Type CLI parsers as real data structures

CLI flag bags must have named types instead of `{}` or untyped objects.

- define a raw flag type for string/boolean CLI values;
- define a parsed options type for validated runtime values;
- keep hyphenated flags as quoted keys, for example `"dry-run"`;
- normalize aliases into one canonical parsed property.

This prevents `TS2339` and `TS7053` diagnostics for parsed option objects.

### Preserve literal unions for defaults

When defaults feed union-typed parser results, make the literal type explicit with a named type or `as const`.

Use:

```ts
type Mode = "single" | "multi";
const DEFAULTS = { mode: "single" as Mode };
```

This prevents widening defaults to `string` and later rejecting them as non-assignable to literal unions.

### Type runtime helpers precisely

Process wrappers, command runners, and concurrent workers must declare their input and output shapes.

- command argument arrays are `string[]`;
- command result objects have explicit fields and types;
- `new Promise` calls include the resolved type when no value is returned, for example `new Promise<void>(...)`;
- `catch` callbacks and top-level `.catch` handlers accept `unknown` and format the error explicitly.

This keeps failures observable while satisfying strict compiler settings.
