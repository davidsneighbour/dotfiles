import { createHash } from "node:crypto";
import { z } from "zod";

// Preserve future Google fields, including those not yet understood by the manager.
export const subscriptionSchema = z
  .object({
    query: z.string().min(1),
    language: z.string().optional(),
    country: z.string().optional(),
    applyLanguageRestrict: z.boolean().optional(),
    applyRegionRestrict: z.boolean().optional(),
    source: z.array(z.string()).optional(),
    quality: z.union([z.string(), z.array(z.string())]).optional(),
    deliveryMethod: z.string().optional(),
    deliveryFrequency: z.string().optional(),
    deliveryTime: z
      .object({
        timezoneCode: z.string(),
        hourOfDay: z.number().int(),
        dayOfWeek: z.number().int(),
      })
      .passthrough()
      .optional(),
    emailAddress: z.string().optional(),
  })
  .passthrough();
export const takeoutSchema = z
  .object({ subscriptions: z.array(subscriptionSchema).max(10000) })
  .passthrough();
export type Subscription = z.infer<typeof subscriptionSchema>;
export function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value !== null && typeof value === "object")
    return `{${Object.entries(value)
      .sort(([a], [b]) => a.localeCompare(b, "en"))
      .map(([k, v]) => `${JSON.stringify(k)}:${canonical(v)}`)
      .join(",")}}`;
  return JSON.stringify(value);
}
export function hash(value: unknown): string {
  return createHash("sha256").update(canonical(value)).digest("hex");
}
export function bytesHash(value: Buffer): string {
  return createHash("sha256").update(value).digest("hex");
}
export const importedSchema = z
  .object({
    id: z.string(),
    fingerprint: z.string(),
    record: subscriptionSchema,
  })
  .strict();
export type Imported = z.infer<typeof importedSchema>;
export function identify(records: Subscription[]): Imported[] {
  const counts = new Map<string, number>();
  return records.map((record) => {
    const fingerprint = hash(record);
    const occurrence = (counts.get(fingerprint) ?? 0) + 1;
    counts.set(fingerprint, occurrence);
    return { id: `import-${fingerprint}-${occurrence}`, fingerprint, record };
  });
}
export function duplicateGroups(records: Imported[]): string[][] {
  const groups = new Map<string, string[]>();
  for (const r of records)
    groups.set(r.fingerprint, [...(groups.get(r.fingerprint) ?? []), r.id]);
  return [...groups.values()].filter((ids) => ids.length > 1);
}
export const stateSchema = z
  .object({
    schemaVersion: z.literal(1),
    initialSource: z.literal("authoritative-takeout"),
    initialDigest: z.string(),
    imports: z.array(
      z
        .object({
          digest: z.string(),
          snapshot: z.string(),
          count: z.number().int().nonnegative(),
        })
        .strict(),
    ),
    initial: z.array(importedSchema),
    managed: z.array(
      z
        .object({
          importId: z.string(),
          baseline: subscriptionSchema,
          providerId: z.string().optional(),
        })
        .strict(),
    ),
  })
  .strict()
  .superRefine((state, ctx) => {
    const expected = identify(state.initial.map((i) => i.record));
    if (
      state.initial.some(
        (r, i) =>
          r.id !== expected[i]?.id ||
          r.fingerprint !== expected[i]?.fingerprint,
      )
    )
      ctx.addIssue({
        code: "custom",
        message: "Initial inventory integrity failure",
      });
    const owners = state.managed.map((m) => m.importId);
    if (
      new Set(owners).size !== owners.length ||
      owners.some((id) => !state.initial.some((r) => r.id === id))
    )
      ctx.addIssue({ code: "custom", message: "Invalid ownership identity" });
    const providers = state.managed.flatMap((m) =>
      m.providerId ? [m.providerId] : [],
    );
    if (new Set(providers).size !== providers.length)
      ctx.addIssue({
        code: "custom",
        message: "Duplicate managed provider identity",
      });
    if (
      state.imports.some(
        (i) =>
          !/^[a-f0-9]{64}$/.test(i.digest) ||
          i.snapshot !== "snapshots/" + i.digest + ".json",
      )
    )
      ctx.addIssue({ code: "custom", message: "Invalid snapshot reference" });
  });
export type State = z.infer<typeof stateSchema>;
