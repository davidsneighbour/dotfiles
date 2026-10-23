import { execFile } from "node:child_process";
import { randomBytes } from "node:crypto";
import { readFile, realpath } from "node:fs/promises";
import { createServer } from "node:http";
import { dirname } from "node:path";
import type { Config } from "./core.ts";
import { inside, openDatabase, status, verifyDrive } from "./core.ts";
import type { SearchOptions } from "./search.ts";
import { search } from "./search.ts";

export async function serve(
  config: Config,
): Promise<ReturnType<typeof createServer>> {
  const db = await openDatabase(config);
  const token = randomBytes(32).toString("hex");
  const origin = `http://127.0.0.1:${config.port}`;
  let searching = false;
  const server = createServer(async (req, res) => {
    res.setHeader("Cache-Control", "no-store");
    res.setHeader("X-Content-Type-Options", "nosniff");
    res.setHeader(
      "Content-Security-Policy",
      "default-src 'self'; img-src 'self' data:; script-src 'self'; style-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'",
    );
    try {
      if (req.headers.host !== `127.0.0.1:${config.port}`)
        throw Error("Use the local 127.0.0.1 address.");
      const url = new URL(req.url ?? "/", origin);
      if (
        req.method === "GET" &&
        ["/", "/app.js", "/style.css"].includes(url.pathname)
      ) {
        const name =
          url.pathname === "/" ? "index.html" : url.pathname.slice(1);
        res.setHeader(
          "Content-Type",
          name.endsWith(".js")
            ? "text/javascript"
            : name.endsWith(".css")
              ? "text/css"
              : "text/html",
        );
        res.end(await readFile(new URL(`../web/${name}`, import.meta.url)));
        return;
      }
      res.setHeader("Content-Type", "application/json");
      if (req.method === "GET" && url.pathname === "/api/status") {
        let online = true;
        try {
          await verifyDrive(config);
        } catch {
          online = false; /* Offline browsing is supported. */
        }
        res.end(
          JSON.stringify({ ...status(db), online, root: config.root, token }),
        );
        return;
      }
      if (req.method === "GET" && url.pathname === "/api/search") {
        if (searching) {
          res.statusCode = 429;
          res.end(
            JSON.stringify({
              error: "A search is already running. Try again shortly.",
            }),
          );
          return;
        }
        searching = true;
        try {
          res.end(
            JSON.stringify(
              await search(
                config.database,
                Object.fromEntries(url.searchParams) as SearchOptions,
              ),
            ),
          );
        } finally {
          searching = false;
        }
        return;
      }
      if (req.method === "POST" && url.pathname === "/api/open") {
        if (
          req.headers.origin !== origin ||
          req.headers["x-storage-token"] !== token
        )
          throw Error("Open requests must come from this search page.");
        const id = Number(url.searchParams.get("id"));
        const row = db
          .prepare("SELECT path,kind FROM entries WHERE id=?")
          .get(id);
        if (!row)
          throw Error("Entry no longer exists in the index. Search again.");
        await verifyDrive(config);
        const path =
          url.searchParams.get("folder") === "true" && row.kind !== "directory"
            ? dirname(String(row.path))
            : String(row.path);
        const actual = await realpath(path);
        if (!inside(config.root, actual))
          throw Error("This link points outside the indexed storage drive.");
        await new Promise<void>((resolve, reject) =>
          execFile(
            "/usr/bin/xdg-open",
            [actual],
            {
              timeout: 15_000,
              env: { ...process.env, ...config.openerEnvironment },
            },
            (error) => (error ? reject(error) : resolve()),
          ),
        );
        res.end(JSON.stringify({ ok: true }));
        return;
      }
      res.statusCode = 404;
      res.end(JSON.stringify({ error: "Not found." }));
    } catch (error) {
      res.statusCode = 400;
      res.setHeader("Content-Type", "application/json");
      res.end(
        JSON.stringify({
          error: error instanceof Error ? error.message : String(error),
        }),
      );
    }
  });
  server.on("close", () => db.close());
  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.listen(config.port, "127.0.0.1", resolve);
  });
  console.log(`Storage search: ${origin}`);
  return server;
}
