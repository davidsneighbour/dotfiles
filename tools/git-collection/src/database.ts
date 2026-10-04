import { chmodSync, existsSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { DatabaseSync } from "node:sqlite";

export function openDatabase(path: string, initialise = false): DatabaseSync {
  if (initialise) mkdirSync(dirname(path), { recursive: true, mode: 0o700 });
  const isNew = !existsSync(path);
  const db = new DatabaseSync(path, { readOnly: !initialise });
  try {
    if (isNew && initialise) chmodSync(path, 0o600);
    db.exec("PRAGMA foreign_keys = ON; PRAGMA busy_timeout = 5000;");
    const version = db.prepare("PRAGMA user_version").get()?.user_version;
    if (version === 0 && initialise) {
      db.exec(`BEGIN IMMEDIATE;
        CREATE TABLE repositories (
          id TEXT PRIMARY KEY, path TEXT NOT NULL UNIQUE, name TEXT NOT NULL,
          object_format TEXT NOT NULL CHECK(object_format IN ('sha1', 'sha256')),
          remotes_json TEXT NOT NULL, shallow INTEGER NOT NULL,
          first_seen TEXT NOT NULL, last_seen TEXT NOT NULL, last_scan TEXT,
          scan_state TEXT NOT NULL CHECK(scan_state IN ('pending', 'complete', 'failed'))
        ) STRICT;
        CREATE TABLE collection_runs (
          id INTEGER PRIMARY KEY, repository_path TEXT NOT NULL,
          started_at TEXT NOT NULL, finished_at TEXT,
          state TEXT NOT NULL CHECK(state IN ('running', 'complete', 'failed')),
          commits_seen INTEGER NOT NULL DEFAULT 0, commits_added INTEGER NOT NULL DEFAULT 0,
          error TEXT
        ) STRICT;
        CREATE TABLE commits (
          repository_id TEXT NOT NULL REFERENCES repositories(id), hash TEXT NOT NULL,
          author_name TEXT NOT NULL, author_email TEXT NOT NULL, author_date TEXT NOT NULL,
          committer_name TEXT NOT NULL, committer_email TEXT NOT NULL, committer_date TEXT NOT NULL,
          subject TEXT NOT NULL, body TEXT NOT NULL, parent_count INTEGER NOT NULL,
          collected_at TEXT NOT NULL,
          PRIMARY KEY(repository_id, hash)
        ) STRICT;
        CREATE INDEX commits_hash ON commits(hash);
        CREATE INDEX commits_author ON commits(author_email);
        CREATE INDEX commits_author_date ON commits(author_date);
        CREATE INDEX commits_committer_date ON commits(committer_date);
        PRAGMA user_version = 1;
        COMMIT;`);
    } else if (typeof version !== "number" || version < 1 || version > 3) {
      throw new Error(
        `Unsupported schema version ${String(version)}. Use init for an empty database.`,
      );
    }
    const current = db.prepare("PRAGMA user_version").get()?.user_version;
    if (current === 1) {
      if (!initialise)
        throw new Error(
          "Schema upgrade required. Run init to migrate this database.",
        );
      db.exec(`BEGIN IMMEDIATE;
        ALTER TABLE repositories ADD COLUMN tips_json TEXT;
        ALTER TABLE commits ADD COLUMN reachability TEXT NOT NULL DEFAULT 'unknown'
          CHECK(reachability IN ('reachable', 'unreachable', 'unknown'));
        ALTER TABLE collection_runs ADD COLUMN mode TEXT NOT NULL DEFAULT 'full';
        ALTER TABLE collection_runs ADD COLUMN duration_ms INTEGER;
        CREATE TABLE scan_runs (
          id INTEGER PRIMARY KEY, started_at TEXT NOT NULL, finished_at TEXT,
          state TEXT NOT NULL CHECK(state IN ('running', 'complete', 'failed')),
          repositories_scanned INTEGER NOT NULL DEFAULT 0,
          repositories_changed INTEGER NOT NULL DEFAULT 0,
          commits_added INTEGER NOT NULL DEFAULT 0,
          failures INTEGER NOT NULL DEFAULT 0, summary_json TEXT
        ) STRICT;
        CREATE VIRTUAL TABLE commit_search USING fts5(subject, body, author, repository,
          content='', tokenize='unicode61');
        CREATE TRIGGER commits_search_insert AFTER INSERT ON commits BEGIN
          INSERT INTO commit_search(rowid, subject, body, author, repository)
          VALUES (new.rowid, new.subject, new.body, new.author_name || ' ' || new.author_email,
            (SELECT name FROM repositories WHERE id=new.repository_id));
        END;
        CREATE TRIGGER commits_search_delete AFTER DELETE ON commits BEGIN
          INSERT INTO commit_search(commit_search, rowid, subject, body, author, repository)
          VALUES ('delete', old.rowid, old.subject, old.body, old.author_name || ' ' || old.author_email,
            (SELECT name FROM repositories WHERE id=old.repository_id));
        END;
        CREATE TRIGGER commits_search_update AFTER UPDATE OF subject, body, author_name, author_email ON commits BEGIN
          INSERT INTO commit_search(commit_search, rowid, subject, body, author, repository)
          VALUES ('delete', old.rowid, old.subject, old.body, old.author_name || ' ' || old.author_email,
            (SELECT name FROM repositories WHERE id=old.repository_id));
          INSERT INTO commit_search(rowid, subject, body, author, repository)
          VALUES (new.rowid, new.subject, new.body, new.author_name || ' ' || new.author_email,
            (SELECT name FROM repositories WHERE id=new.repository_id));
        END;
        CREATE TRIGGER repository_search_rename BEFORE UPDATE OF name ON repositories BEGIN
          INSERT INTO commit_search(commit_search, rowid, subject, body, author, repository)
            SELECT 'delete', rowid, subject, body, author_name || ' ' || author_email, old.name
            FROM commits WHERE repository_id=old.id;
          INSERT INTO commit_search(rowid, subject, body, author, repository)
            SELECT rowid, subject, body, author_name || ' ' || author_email, new.name
            FROM commits WHERE repository_id=old.id;
        END;
        INSERT INTO commit_search(rowid, subject, body, author, repository)
          SELECT c.rowid, c.subject, c.body, c.author_name || ' ' || c.author_email, r.name
          FROM commits c JOIN repositories r ON r.id=c.repository_id;
        CREATE VIEW v_commits AS SELECT c.*, r.name AS repository, r.path AS repository_path,
          r.shallow, date(c.committer_date, '+7 hours') AS activity_date,
          strftime('%Y-%m', c.committer_date, '+7 hours') AS activity_month
          FROM commits c JOIN repositories r ON r.id=c.repository_id;
        CREATE VIEW v_recent_commits AS SELECT * FROM v_commits
          WHERE unixepoch(committer_date) >= unixepoch('now', '-30 days');
        CREATE VIEW v_daily_activity AS SELECT activity_date, count(*) AS commits
          FROM v_commits GROUP BY activity_date;
        CREATE VIEW v_monthly_activity AS SELECT activity_month, count(*) AS commits
          FROM v_commits GROUP BY activity_month;
        CREATE VIEW v_repository_activity AS SELECT repository_id, repository, count(*) AS commits,
          datetime(min(unixepoch(committer_date)), 'unixepoch') AS first_commit,
          datetime(max(unixepoch(committer_date)), 'unixepoch') AS last_commit
          FROM v_commits GROUP BY repository_id;
        CREATE VIEW v_repository_daily_activity AS SELECT repository_id, repository, activity_date,
          count(*) AS commits FROM v_commits GROUP BY repository_id, activity_date;
        CREATE VIEW v_author_activity AS SELECT author_email, count(*) AS commits,
          count(DISTINCT repository_id) AS repositories FROM commits GROUP BY author_email;
        PRAGMA user_version=2;
        COMMIT;`);
    }
    if (db.prepare("PRAGMA user_version").get()?.user_version === 2) {
      if (!initialise)
        throw new Error(
          "Schema upgrade required. Run init to migrate this database.",
        );
      db.exec(`BEGIN IMMEDIATE;
        CREATE TABLE commit_enrichment (
          repository_id TEXT NOT NULL, hash TEXT NOT NULL,
          files_changed INTEGER, insertions INTEGER, deletions INTEGER, binary_files INTEGER,
          files_complete INTEGER NOT NULL DEFAULT 0,
          state TEXT NOT NULL CHECK(state IN ('complete', 'failed')), error TEXT, enriched_at TEXT NOT NULL,
          PRIMARY KEY(repository_id, hash),
          FOREIGN KEY(repository_id, hash) REFERENCES commits(repository_id, hash) ON DELETE CASCADE
        ) STRICT;
        CREATE TABLE commit_files (
          repository_id TEXT NOT NULL, hash TEXT NOT NULL, path TEXT NOT NULL,
          status TEXT NOT NULL, insertions INTEGER, deletions INTEGER,
          PRIMARY KEY(repository_id, hash, path),
          FOREIGN KEY(repository_id, hash) REFERENCES commits(repository_id, hash) ON DELETE CASCADE
        ) STRICT;
        PRAGMA user_version=3;
        COMMIT;`);
    }
    return db;
  } catch (error) {
    db.close();
    throw error;
  }
}

export function rebuildSearch(db: DatabaseSync): void {
  db.exec("BEGIN IMMEDIATE");
  try {
    db.exec(`
    INSERT INTO commit_search(commit_search) VALUES ('delete-all');
    INSERT INTO commit_search(rowid, subject, body, author, repository)
      SELECT c.rowid, c.subject, c.body, c.author_name || ' ' || c.author_email, r.name
      FROM commits c JOIN repositories r ON r.id=c.repository_id;
    COMMIT;`);
  } catch (error) {
    db.exec("ROLLBACK");
    throw error;
  }
}

export function verifyDatabase(db: DatabaseSync): void {
  const checks = db.prepare("PRAGMA integrity_check").all();
  if (checks.length !== 1 || checks[0]?.integrity_check !== "ok") {
    throw new Error(
      "SQLite integrity check failed. Restore a verified snapshot or rebuild.",
    );
  }
  if (db.prepare("PRAGMA foreign_key_check").all().length > 0) {
    throw new Error(
      "SQLite foreign key check failed. Restore a verified snapshot or rebuild.",
    );
  }
  if (
    db.prepare("SELECT count(*) AS count FROM commit_search").get()?.count !==
    db.prepare("SELECT count(*) AS count FROM commits").get()?.count
  ) {
    throw new Error(
      "Search index row count differs from commits. Run reindex, then verify again.",
    );
  }
}
