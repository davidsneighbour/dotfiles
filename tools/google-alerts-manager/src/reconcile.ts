import { z } from "zod";
import type { Desired } from "./config.ts";
import type { State } from "./model.ts";
import { duplicateGroups, hash, subscriptionSchema } from "./model.ts";
export const observationSchema = z
  .object({
    schemaVersion: z.literal(1),
    origin: z.literal("browser"),
    capturedAt: z.iso.datetime(),
    accountVerified: z.literal(true),
    alerts: z.array(
      z
        .object({
          providerId: z.string().optional(),
          record: subscriptionSchema,
        })
        .strict(),
    ),
  })
  .strict()
  .superRefine((o, ctx) => {
    const ids = o.alerts.flatMap((a) => (a.providerId ? [a.providerId] : []));
    if (new Set(ids).size !== ids.length)
      ctx.addIssue({
        code: "custom",
        message: "Duplicate provider identities",
      });
  });
export type Observation = z.infer<typeof observationSchema>;
export function adoptionPlan(state: State) {
  const duplicates = duplicateGroups(state.initial);
  const blocked = new Set(duplicates.flat());
  const eligible = state.initial
    .filter(
      (r) =>
        !blocked.has(r.id) && !state.managed.some((m) => m.importId === r.id),
    )
    .map((r) => r.id);
  return {
    digest: hash({ initialDigest: state.initialDigest, eligible, duplicates }),
    eligible,
    duplicates,
    alreadyManaged: state.managed.length,
    source: state.initialSource,
  };
}
export function adopt(state: State, approval: string): State {
  const plan = adoptionPlan(state);
  if (approval !== plan.digest)
    throw new Error("Approval does not match the current adoption plan");
  if (plan.duplicates.length)
    throw new Error("Ambiguous duplicate records require manual resolution");
  return {
    ...state,
    managed: [
      ...state.managed,
      ...state.initial
        .filter((r) => plan.eligible.includes(r.id))
        .map((r) => ({ importId: r.id, baseline: r.record })),
    ],
  };
}
export type Operation = {
  key: string;
  action:
    | "create"
    | "update"
    | "unchanged"
    | "adopt"
    | "conflict"
    | "missing"
    | "unmanaged"
    | "delete-proposed"
    | "paused";
  reason: string;
};
export function reconcile(
  state: State,
  desired: Desired[],
  observation?: Observation,
) {
  const observed =
    observation?.alerts ??
    state.initial.map((i) => ({ record: i.record, providerId: undefined }));
  const used = new Set<number>();
  const operations: Operation[] = [];
  for (const d of desired) {
    if (
      d.enabled &&
      desired.filter(
        (other) => other.enabled && hash(other.record) === hash(d.record),
      ).length > 1
    ) {
      operations.push({
        key: d.key,
        action: "conflict",
        reason: "Multiple active definitions resolve to an identical alert",
      });
      continue;
    }
    const owner = state.managed.find((m) => m.importId === d.inherit);
    const initial = state.initial.find((i) => i.id === d.inherit);
    if (!d.enabled) {
      operations.push({
        key: d.key,
        action: "paused",
        reason: "Inactive definitions never trigger removal",
      });
      continue;
    }
    const baseline = owner?.baseline ?? initial?.record;
    const matches = observed
      .map((r, i) => ({ ...r, i }))
      .filter((r) =>
        owner?.providerId
          ? r.providerId === owner.providerId
          : baseline
            ? hash(r.record) === hash(baseline)
            : hash(r.record) === hash(d.record),
      );
    if (matches.length > 1 || matches.some((r) => used.has(r.i))) {
      operations.push({
        key: d.key,
        action: "conflict",
        reason: "Identity is ambiguous",
      });
      continue;
    }
    const match = matches[0];
    if (match) used.add(match.i);
    if (!owner) {
      operations.push({
        key: d.key,
        action: initial
          ? match
            ? "adopt"
            : "missing"
          : match
            ? "unmanaged"
            : "create",
        reason: initial
          ? "Explicit ownership approval required"
          : match
            ? "Existing alert requires adoption"
            : "New reviewed alert",
      });
    } else if (!match)
      operations.push({
        key: d.key,
        action: "missing",
        reason: "Managed alert not found; never recreate automatically",
      });
    else if (hash(match.record) === hash(d.record))
      operations.push({
        key: d.key,
        action: "unchanged",
        reason: "Desired state is present",
      });
    else if (hash(match.record) !== hash(owner.baseline))
      operations.push({
        key: d.key,
        action: "conflict",
        reason: "Observed state differs from the baseline",
      });
    else
      operations.push({
        key: d.key,
        action: "update",
        reason: "Reviewed local change; delivery settings are inherited",
      });
  }
  for (const owner of state.managed) {
    if (!desired.some((d) => d.inherit === owner.importId))
      operations.push({
        key: owner.importId,
        action: "delete-proposed",
        reason: "Definition removed; deletion is never automatic",
      });
  }
  for (const [i] of observed.entries())
    if (!used.has(i))
      operations.push({
        key: `observed-${i + 1}`,
        action: "unmanaged",
        reason: "No active unambiguous ownership match",
      });
  const source = observation ? "browser" : "authoritative-takeout";
  return {
    schemaVersion: 1,
    source,
    executable: false,
    digest: hash({ operations, desired, observed, managed: state.managed }),
    operations,
  };
}
