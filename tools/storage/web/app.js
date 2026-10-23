const form = document.querySelector("#search");
const results = document.querySelector("#results");
const errorBox = document.querySelector("#error");
const count = document.querySelector("#count");
let offset = 0;
let hash = "";
let token = "";
let online = false;
let requestNumber = 0;
const number = (n) => Number(n ?? 0).toLocaleString("en-GB");
const date = (n) =>
  n
    ? new Date(Number(n)).toLocaleDateString("en-GB", { timeZone: "UTC" })
    : "unavailable";
const bytes = (n) => {
  const value = Number(n);
  if (value < 1024) return `${value} B`;
  const unit = Math.min(Math.floor(Math.log(value) / Math.log(1024)), 4);
  return `${(value / 1024 ** unit).toFixed(1)} ${["B", "KiB", "MiB", "GiB", "TiB"][unit]}`;
};
function node(tag, text, className) {
  const el = document.createElement(tag);
  el.textContent = text;
  if (className) el.className = className;
  return el;
}
function showError(error) {
  errorBox.textContent = error.message;
  errorBox.hidden = false;
}
async function json(url, options) {
  const res = await fetch(url, options);
  const data = await res.json();
  if (!res.ok) throw Error(data.error || `Request failed (${res.status})`);
  return data;
}
async function refreshStatus() {
  try {
    const s = await json("/api/status");
    token = s.token;
    online = s.online;
    document.querySelector("#drive").textContent =
      `${s.root} — ${online ? "connected" : "disconnected; catalogue available"}`;
    document.querySelector("#coverage").textContent =
      `${number(s.files)} files and ${number(s.folders)} folders indexed. ${number(s.hashed)} files hashed; ${bytes(s.pendingBytes)} pending. ${number(s.errors)} entries with errors; ${number(s.meta.scanErrors)} traversal errors on the last scan.`;
    document.querySelector("#progress").textContent =
      `${s.meta.phase || "No scan yet"}. Last name scan: ${s.meta.scanFinished ? new Date(s.meta.scanFinished).toLocaleString("en-GB") : "not completed"}.`;
  } catch (error) {
    showError(error);
  }
}
async function openEntry(id, folder) {
  try {
    await json(`/api/open?id=${id}&folder=${folder}`, {
      method: "POST",
      headers: { "X-Storage-Token": token },
    });
  } catch (error) {
    showError(error);
  }
}
async function runSearch() {
  const current = ++requestNumber;
  errorBox.hidden = true;
  count.textContent = "Searching…";
  const params = new URLSearchParams(new FormData(form));
  params.set("offset", String(offset));
  if (hash) params.set("hash", hash);
  document.querySelector("#clear-hash").hidden = !hash;
  document.querySelector("#result-title").textContent = hash
    ? "Occurrences of the same content"
    : params.get("q")
      ? "Search results"
      : "All indexed entries";
  try {
    const data = await json(`/api/search?${params}`);
    if (current !== requestNumber) return;
    results.replaceChildren();
    count.textContent = `${number(data.total)} occurrences`;
    if (!data.rows.length)
      results.append(
        node(
          "p",
          "No matches. Try fewer filters, or check whether the first name scan has finished.",
          "empty",
        ),
      );
    for (const row of data.rows) {
      const article = node("article", "", "result");
      const info = node("div", "");
      info.append(node("h3", row.name, "name"), node("p", row.path, "path"));
      const meta = node("div", "", "meta");
      for (const text of [
        row.kind,
        row.kind === "file" ? bytes(row.size) : "",
        `Modified ${date(row.mtime)}`,
        `Created ${date(row.birthtime)}`,
        row.kind === "file"
          ? row.hash
            ? `SHA-256 · ${number(row.copies)} content occurrences`
            : "Hash pending"
          : "",
        row.error ? `Index error: ${row.error}` : "",
      ])
        if (text) meta.append(node("span", text));
      info.append(meta);
      const actions = node("div", "", "actions");
      function action(label, callback, disabled = false) {
        const button = node("button", label);
        button.type = "button";
        button.disabled = disabled;
        button.addEventListener("click", callback);
        actions.append(button);
      }
      action("Open folder", () => openEntry(row.id, true), !online);
      if (row.kind === "file")
        action("Open file", () => openEntry(row.id, false), !online);
      action("Copy path", async () => {
        try {
          await navigator.clipboard.writeText(row.path);
          count.textContent = "Path copied";
        } catch (error) {
          showError(error);
        }
      });
      if (row.hash)
        action("Same content", () => {
          form.reset();
          hash = row.hash;
          offset = 0;
          void runSearch();
        });
      article.append(info, actions);
      results.append(article);
    }
    document.querySelector("#previous").disabled = offset === 0;
    document.querySelector("#next").disabled =
      offset + data.limit >= data.total;
    document.querySelector("#page").textContent = data.total
      ? `${number(offset + 1)}–${number(Math.min(offset + data.limit, data.total))} of ${number(data.total)}`
      : "0 results";
  } catch (error) {
    if (current === requestNumber) {
      count.textContent = "Search failed";
      showError(error);
    }
  }
}
form.addEventListener("submit", (event) => {
  event.preventDefault();
  offset = 0;
  hash = "";
  void runSearch();
});
document.querySelector("#previous").addEventListener("click", () => {
  offset = Math.max(0, offset - 100);
  void runSearch();
});
document.querySelector("#next").addEventListener("click", () => {
  offset += 100;
  void runSearch();
});
document.querySelector("#clear-hash").addEventListener("click", () => {
  hash = "";
  offset = 0;
  void runSearch();
});
void refreshStatus().then(runSearch);
setInterval(refreshStatus, 15000);
