import type {
  ProviderDoctorResult,
  UsageProvider,
} from "../providers/provider.ts";

function mark(value: boolean): string {
  return value ? "ok" : "fail";
}

export async function runDoctor(providers: UsageProvider[]): Promise<{
  ok: boolean;
  output: string;
}> {
  const results = await Promise.all(
    providers.map((provider) => provider.doctor()),
  );
  const output = results.map(renderDoctorResult).join("\n\n");
  const ok = results.every((result) =>
    result.checks.every((check) => check.ok),
  );

  return { ok, output };
}

function renderDoctorResult(result: ProviderDoctorResult): string {
  const lines = [result.displayName];

  for (const check of result.checks) {
    const detail = check.detail ? `  ${check.detail}` : "";
    lines.push(`  ${check.label.padEnd(16)} ${mark(check.ok)}${detail}`);
  }

  return lines.join("\n");
}
