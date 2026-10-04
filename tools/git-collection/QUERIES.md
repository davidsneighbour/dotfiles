# Example queries

Run these queries in DBeaver, Datasette, or another SQLite client. Counts include repository/commit pairs, retained rewritten history, and separate clones. Use reachability filters when you want only the last observed reachable history. Activity dates use committer time in Asia/Bangkok.

## Recent commits

```sql
SELECT repository, hash, author_name, committer_date, subject, reachability
FROM v_recent_commits
ORDER BY unixepoch(committer_date) DESC
LIMIT 100;
```

## Daily and monthly activity

```sql
SELECT * FROM v_daily_activity
ORDER BY activity_date DESC
LIMIT 90;

SELECT * FROM v_monthly_activity
ORDER BY activity_month DESC;
```

## Repository and author activity

```sql
SELECT * FROM v_repository_activity
ORDER BY commits DESC;

SELECT * FROM v_repository_daily_activity
WHERE repository = 'dotfiles'
ORDER BY activity_date DESC;

SELECT * FROM v_author_activity
ORDER BY commits DESC;
```

Repository names are display labels. Filter by `repository_id` to select one specific local clone.

## Search messages

```sql
SELECT r.name AS repository, c.hash, c.subject, c.committer_date
FROM commit_search
JOIN commits c ON c.rowid = commit_search.rowid
JOIN repositories r ON r.id = c.repository_id
WHERE commit_search MATCH '"reduced motion"'
ORDER BY bm25(commit_search), unixepoch(c.committer_date) DESC
LIMIT 100;
```

## Reachable activity and unique objects

```sql
SELECT activity_date, count(*) AS commits
FROM v_commits
WHERE reachability = 'reachable'
GROUP BY activity_date
ORDER BY activity_date DESC;

SELECT count(*) AS unique_commit_objects
FROM (
  SELECT r.object_format, c.hash
  FROM commits c
  JOIN repositories r ON r.id = c.repository_id
  GROUP BY r.object_format, c.hash
);
```

Unique-object counting removes duplicate clones from the count; it does not imply that those clones are the same repository.

## Failed and interrupted scans

```sql
SELECT repository_path, started_at, state, error, duration_ms
FROM collection_runs
WHERE state != 'complete'
ORDER BY started_at DESC;

SELECT started_at, state, repositories_scanned, commits_added, failures
FROM scan_runs
ORDER BY id DESC
LIMIT 20;
```

A running entry can be an active or interrupted process. Check the process before treating it as abandoned; rerunning collection is safe.

## Optional file statistics

```sql
SELECT r.name AS repository, c.hash, c.subject,
       e.files_changed, e.insertions, e.deletions, e.binary_files
FROM commit_enrichment e
JOIN commits c ON c.repository_id = e.repository_id AND c.hash = e.hash
JOIN repositories r ON r.id = c.repository_id
WHERE e.state = 'complete'
ORDER BY e.files_changed DESC
LIMIT 100;
```

Statistics describe the first-parent change for merges. Binary file counts are separate from numeric insertion/deletion totals. See [README.md](README.md) for resumable enrichment commands.
