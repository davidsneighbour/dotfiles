# MCP server configuration

Configuration files for MCP servers that the repository registers in [`.mcp.json`](../../.mcp.json) (Claude Code) and [`.codex/config.toml`](../../.codex/config.toml) (Codex).

## Ubuntu wiki

[`ubuntu-wiki.json`](ubuntu-wiki.json) configures the [MediaWiki MCP server](https://github.com/ProfessionalWiki/mediawiki-mcp-server) for `https://wiki.ubuntu.com`, as described in [Access the Ubuntu wiki with an MCP server](https://wiki.ubuntu.com/Access_the_Ubuntu_wiki_with_an_MCP_server). Both clients register it as `ubuntu-wiki`.

The setup is read-only and needs no credentials. `readOnly: true` hides all write tools, and `allowWikiManagement: false` hides the tools that add or remove wikis. The remaining tools search and read pages, history, revisions, categories, files, and recent changes.

Both clients load the file from `~/.dotfiles/configs/mcp/ubuntu-wiki.json`, so the path does not depend on the session folder. If the server cannot find the file, it silently falls back to English Wikipedia. Codex does not expand variables in `env`, so its entry starts the server through `bash -c`.

The package version is pinned. To update it, change the version in both client files.
