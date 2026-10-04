# Browse the catalogue

The CLI, SQLite database, and reports work without a graphical interface. Datasette is the optional local browser; DBeaver Community is the optional SQL exploration GUI.

## Local browser

The optional dependency is pinned in [requirements-datasette.txt](requirements-datasette.txt). A folder-local environment keeps it separate from the core collector. From the dotfiles repository root:

```bash
UV_CACHE_DIR=tools/git-collection/state/uv-cache uv venv tools/git-collection/state/datasette-venv
UV_CACHE_DIR=tools/git-collection/state/uv-cache uv pip install --python tools/git-collection/state/datasette-venv/bin/python --requirement tools/git-collection/requirements-datasette.txt
```

If uv is unavailable, create the environment with `python3 -m venv tools/git-collection/state/datasette-venv`, then run that environment's Python with `-m pip install --requirement tools/git-collection/requirements-datasette.txt`. Python packaging is needed only for this optional interface.

Serve the live catalogue on the loopback interface:

```bash
tools/git-collection/state/datasette-venv/bin/datasette serve tools/git-collection/state/catalogue.sqlite --host 127.0.0.1 --port 8001 --metadata tools/git-collection/datasette-metadata.json --setting allow_download off
```

Open `http://127.0.0.1:8001/catalogue`. The `commits` table has message search and facets for repository, author email, and reachability. Activity views provide date and repository summaries. Named queries provide recent commits, daily activity, and a search form. The metadata file assumes the database basename is `catalogue`; change its database key if you use a different basename. The server opens the live file read-only; use an ordinary file argument for a database that continues to change. Use `--immutable` only for a fixed snapshot. These options follow the [Datasette CLI documentation](https://docs.datasette.io/en/stable/cli-reference.html).

Metadata hides operational tables from the default listing; it does not impose access control. Keep this interface on loopback. See the official [search documentation](https://docs.datasette.io/en/stable/full_text_search.html) and [named query documentation](https://docs.datasette.io/en/stable/sql_queries.html#canned-queries) for the interface's query syntax.

Run the optional HTTP checks against an existing catalogue:

```bash
tools/git-collection/state/datasette-venv/bin/python tools/git-collection/tests/datasette-check.py --database tools/git-collection/state/catalogue.sqlite --verbose
```

The check uses Datasette's local test client and does not start a persistent server. Table search and named queries were checked against a fixture catalogue; the live catalogue remains pending until its discovery roots are selected.

## SQL exploration GUI

In DBeaver Community, create a SQLite connection, select the catalogue file, and enable a read-only connection. Expand tables and views, and run the examples in [QUERIES.md](QUERIES.md). This follows DBeaver's [SQLite connection documentation](https://dbeaver.com/docs/dbeaver/Database-driver-SQLite/) and [read-only connection settings](https://dbeaver.com/docs/dbeaver/Managing-security-restrictions-for-database-connection/).

DBeaver is not a system dependency, is not installed by this tool, and has not been tested on the desktop. The tested Datasette interface provides routine exploration without requiring DBeaver.
