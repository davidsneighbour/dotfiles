import { execFileSync } from "node:child_process";
import { mkdir, mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

export function git(repo: string, ...args: string[]): string {
  return execFileSync("git", ["-C", repo, ...args], {
    encoding: "utf8",
    env: {
      ...process.env,
      GIT_CONFIG_GLOBAL: "/dev/null",
      GIT_CONFIG_SYSTEM: "/dev/null",
      GIT_AUTHOR_DATE: "2026-10-01T18:00:00+07:00",
      GIT_COMMITTER_DATE: "2026-10-01T18:00:00+07:00",
    },
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}
export async function fixture(
  t: { after: (fn: () => Promise<void>) => void },
  format = "sha1",
) {
  const root = await mkdtemp(join(tmpdir(), "git-commit-reports-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const repo = join(root, "repo");
  const vault = join(root, "vault");
  await mkdir(repo);
  await mkdir(vault);
  git(repo, "init", "-b", "main", `--object-format=${format}`);
  git(repo, "config", "user.name", "Test Author");
  git(repo, "config", "user.email", "test@example.invalid");
  git(repo, "config", "commit.gpgsign", "false");
  git(
    repo,
    "commit",
    "--allow-empty",
    "-m",
    "feat(test): first\n\nFull message\nwith delimiter-looking text\n---\nand Unicode: สวัสดี\n",
  );
  return { root, repo, vault, hash: git(repo, "rev-parse", "HEAD") };
}
