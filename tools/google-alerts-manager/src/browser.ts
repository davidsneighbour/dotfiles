import { join } from "node:path";
import { chromium } from "playwright";
import { privateDirectory, writePrivate } from "./store.ts";

// Deliberately no create/edit/delete selectors until authenticated discovery validates them.
export async function probeBrowser(root: string): Promise<void> {
  process.umask(0o077);
  const profile = join(root, "browser-profile");
  await privateDirectory(profile);
  const context = await chromium.launchPersistentContext(profile, {
    headless: false,
  });
  try {
    const page = await context.newPage();
    await page.goto("https://www.google.com/alerts", {
      waitUntil: "domcontentloaded",
    });
    if (
      new URL(page.url()).hostname !== "www.google.com" ||
      !new URL(page.url()).pathname.startsWith("/alerts")
    )
      throw new Error("Authentication required; browser discovery stopped");
    // This is private diagnostic evidence, never a verified observation or account proof.
    await writePrivate(
      join(root, "browser-probe.json"),
      JSON.stringify(
        {
          schemaVersion: 1,
          verified: false,
          capturedAt: new Date().toISOString(),
          controls: await page
            .locator(
              'input, button, select, [role="button"], [role="combobox"]',
            )
            .evaluateAll((elements) =>
              elements.map((el) => ({
                tag: el.tagName,
                role: el.getAttribute("role"),
                label: el.getAttribute("aria-label"),
                text: el.textContent,
              })),
            ),
        },
        null,
        2,
      ) + "\n",
    );
  } finally {
    await context.close();
  }
}
export function refuseLiveApply(): never {
  throw new Error(
    "Live sync is disabled: account verification, validated UI adapter, approved plan, and post-write checks are not implemented",
  );
}
