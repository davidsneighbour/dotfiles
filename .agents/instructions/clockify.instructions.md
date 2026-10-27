---
applyTo: "tools/clockify/**"
---

# Clockify rules

* Clockify is the source of truth; local files hold only configuration and short-lived caches, never a competing database.
* Keep the existing single-file CLI structure unless growth justifies a split. Do not introduce a framework.
* Reuse `readJsonFile` / `writeJsonFile` for atomic config/cache I/O and `apiRequest<T>()` for API access. Share underlying operations between CLI commands and form endpoints.
* For form rendering, initial data, lifecycle, or restart behaviour, read [the implementation context](../references/clockify-architecture.md). Preserve first-paint context injection and account for detached restart reporting.
* For client/project API work or related errors, read [the historical API notes](../references/clockify-api.md); confirm current contracts against official documentation before changing behaviour.
* For client/project management features, read [the product decisions](../references/clockify-product.md), including archive-only removal, CLI/UI parity, and modal/swatches behaviour.
