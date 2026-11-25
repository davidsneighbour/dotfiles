import { readFile } from "node:fs/promises";
import { parseDocument } from "yaml";
import { z } from "zod";
import type { State, Subscription } from "./model.ts";

const id = z.string().regex(/^[a-z0-9][a-z0-9-]{0,100}$/);
const settingsSchema = z
  .object({
    language: z.string().min(1),
    country: z.string().min(1),
    applyLanguageRestrict: z.boolean(),
    applyRegionRestrict: z.boolean(),
    source: z.array(z.enum(["NEWS", "WEB"])),
    quality: z.enum(["LOW", "HIGH"]),
    deliveryMethod: z.enum(["EMAIL", "RSS"]),
    deliveryFrequency: z.enum(["HOURLY", "DAILY", "WEEKLY"]),
    emailAddress: z.email(),
    deliveryTime: z
      .object({
        timezoneCode: z.string().min(1),
        hourOfDay: z.number().int(),
        dayOfWeek: z.number().int(),
      })
      .strict(),
  })
  .partial()
  .strict();
const querySchema = z
  .object({
    id,
    expression: z.string().min(1).max(10000),
    status: z.enum(["draft", "active", "paused"]).default("draft"),
    inherit: z
      .string()
      .regex(/^import-[a-f0-9]{64}-[1-9][0-9]*$/)
      .optional(),
    settings: settingsSchema.default({}),
    rationale: z.string().default(""),
    review: z
      .object({
        approved: z.boolean(),
        reviewer: z.string().min(1),
        at: z.iso.datetime(),
      })
      .strict()
      .optional(),
  })
  .strict()
  .superRefine((q, ctx) => {
    if (q.status === "active" && !q.review?.approved)
      ctx.addIssue({
        code: "custom",
        message: "Active queries require manual review approval",
      });
  });
export const configSchema = z
  .object({
    schemaVersion: z.literal(1),
    defaults: settingsSchema.default({}),
    topics: z.array(
      z
        .object({
          id,
          name: z.string().min(1),
          intent: z.string().min(1),
          status: z.enum(["active", "archived"]).default("active"),
          research: z
            .object({
              entities: z.array(z.string()).default([]),
              exclusions: z.array(z.string()).default([]),
              sources: z.array(z.url()).default([]),
              notes: z.string().default(""),
            })
            .strict()
            .optional(),
          settings: settingsSchema.default({}),
          queries: z.array(querySchema).min(1),
        })
        .strict(),
    ),
  })
  .strict()
  .superRefine((config, ctx) => {
    const topics = new Set<string>();
    const imports = new Set<string>();
    for (const t of config.topics) {
      if (topics.has(t.id))
        ctx.addIssue({ code: "custom", message: "Duplicate topic ID" });
      topics.add(t.id);
      const queries = new Set<string>();
      for (const q of t.queries) {
        if (queries.has(q.id))
          ctx.addIssue({ code: "custom", message: "Duplicate query ID" });
        queries.add(q.id);
        if (q.inherit && imports.has(q.inherit))
          ctx.addIssue({
            code: "custom",
            message: "An imported alert can have only one owner",
          });
        if (q.inherit) imports.add(q.inherit);
      }
    }
  });
export type Config = z.infer<typeof configSchema>;
export type Desired = {
  key: string;
  inherit?: string;
  record: Subscription;
  enabled: boolean;
};
export function resolveConfig(config: Config, state?: State): Desired[] {
  return config.topics.flatMap((topic) =>
    topic.queries.map((query) => {
      const imported = query.inherit
        ? state?.initial.find((i) => i.id === query.inherit)
        : undefined;
      if (query.inherit && !imported)
        throw new Error("Unknown inheritance reference");
      // Imported settings bypass defaults. Only explicit topic/query overrides can change them.
      const record: Subscription = imported
        ? {
            ...imported.record,
            ...topic.settings,
            ...query.settings,
            query: query.expression,
          }
        : {
            ...config.defaults,
            ...topic.settings,
            ...query.settings,
            query: query.expression,
          };
      if (!imported && query.status === "active") {
        if (
          !record.deliveryMethod ||
          (record.deliveryMethod === "EMAIL" &&
            (!record.emailAddress || !record.deliveryFrequency))
        )
          throw new Error(
            "New active alerts require explicit delivery settings",
          );
      }
      return {
        key: `${topic.id}/${query.id}`,
        inherit: query.inherit,
        record,
        enabled: topic.status === "active" && query.status === "active",
      };
    }),
  );
}
export async function readConfig(path: string): Promise<Config> {
  try {
    const text = await readFile(path, "utf8");
    if (Buffer.byteLength(text) > 1024 * 1024) throw new Error();
    const document = parseDocument(text, { uniqueKeys: true });
    if (document.errors.length) throw new Error();
    return configSchema.parse(document.toJS({ maxAliasCount: 30 }));
  } catch {
    throw new Error("Invalid YAML configuration (values withheld)");
  }
}
export function candidateConfig(state: State): Config {
  return configSchema.parse({
    schemaVersion: 1,
    defaults: {},
    topics: state.initial.map((r, i) => ({
      id: `imported-${i + 1}`,
      name: `Imported alert ${i + 1}`,
      intent: "Preserve the imported query; review and classify manually.",
      queries: [
        {
          id: "original",
          expression: r.record.query,
          status: "draft",
          inherit: r.id,
          rationale:
            "Unchanged authoritative Takeout query; adoption and query review are pending.",
        },
      ],
    })),
  });
}
