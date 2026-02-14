You are seeing **“Checksum mismatch of archived document”**. That is specifically the **PDF/A “archive” file** that Paperless generates from the original, not the original itself. The sanity checker compares the checksum stored in the database with the current file content on disk. ([Paperless-ngx][1])

## Why this happens (most common causes)

* **The archive file changed after Paperless recorded its checksum**:

  * Paperless was upgraded and the archiver/OCR pipeline regenerated archives differently (this can legitimately change archive bytes).
  * Something (outside Paperless) modified files in the `paperless_media` volume (sync tool, backup/restore tool, manual edits, permissions/ownership “fixups”, antivirus, etc.). Maintainers explicitly point to “something changing the files outside of paperless” as the root cause pattern. ([GitHub][2])
* **Storage/FS issues** (more likely on Pi setups if power or storage is flaky):

  * SD card / USB disk corruption, partial writes, sudden power loss.
  * Network mounts with inconsistent caching.

Because your messages are **archive checksum mismatches**, the first-line fix is usually safe: **regenerate the archive**.

## What to do next (triage + repair)

### Step 1: Confirm scope with the built-in sanity checker

Paperless provides `document_sanity_checker` (no args) to enumerate these issues. ([Paperless-ngx][1])

On Docker Compose, run it inside the webserver container (service name may be `webserver` in your compose):

```bash
docker compose exec -T webserver python3 manage.py document_sanity_checker
```

(If your service is named differently, use `docker compose ps` to see it.)

### Step 2: For each document id, regenerate the archive

Paperless documents that command as:

`document_archiver --overwrite --document <id>` ([Paperless-ngx][1])

Run it for the ids shown in your logs:

```bash
docker compose exec -T webserver python3 manage.py document_archiver --overwrite --document 199
docker compose exec -T webserver python3 manage.py document_archiver --overwrite --document 197
docker compose exec -T webserver python3 manage.py document_archiver --overwrite --document 195
docker compose exec -T webserver python3 manage.py document_archiver --overwrite --document 158
docker compose exec -T webserver python3 manage.py document_archiver --overwrite --document 156
docker compose exec -T webserver python3 manage.py document_archiver --overwrite --document 116
```

This “redo archive” path is exactly what the maintainers recommend for **archive checksum mismatches** (redo OCR/archiving to regenerate and update checksum). ([GitHub][2])

### Step 3: Re-run sanity checker and confirm they are gone

```bash
docker compose exec -T webserver python3 manage.py document_sanity_checker
```

## How to identify “which documents need which procedure”

You can classify by the sanity checker output type:

* **“Checksum mismatch of archived document”**

  * Procedure: regenerate with `document_archiver --overwrite --document <id>` ([Paperless-ngx][1])
* **“Checksum mismatch of document”** (original mismatch)

  * Higher risk: it implies the *original* file changed or is corrupted.
  * Procedure: download the original from the UI/API, compare to your source of truth (email attachment, supplier portal, etc.), restore from backup if needed. (Do not “just update the checksum” unless you fully understand why it changed.)

## If the mismatch comes back again

That strongly suggests **something is modifying files outside Paperless** (or storage corruption). ([GitHub][2])
In that case, the next diagnostic step is to identify the archive file paths and watch them for changes (inotify/audit), and check your storage stack (disk health, power, mounts, sync jobs).

If you paste your `docker-compose.yml` service names and the volume mappings for `paperless_media`, I will give you exact commands to:

* locate the archive file paths for those document ids, and
* verify whether anything is touching them outside Paperless.

[1]: https://docs.paperless-ngx.com/administration/ "Administration - Paperless-ngx"
[2]: https://github.com/paperless-ngx/paperless-ngx/discussions/1767 "Sanity Checker find checksum mismatches · paperless-ngx paperless-ngx · Discussion #1767 · GitHub"
