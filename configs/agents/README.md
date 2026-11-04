# Global agent instructions

[global-agents-instructions.md](global-agents-instructions.md) contains the user-wide instructions loaded by Claude Code and Codex in every session. It is not a repository instruction file. Its source filename avoids automatic discovery as a local `AGENTS.md` or `CLAUDE.md`.

The [Dotbot AI profile](../dotbot/config.ai.yaml) links this source to `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`. Edit the source here to update the shared instructions.
