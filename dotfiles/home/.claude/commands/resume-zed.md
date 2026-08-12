---
description: List Claude Code threads started by Zed's ACP client for this project, with ready-to-run resume commands. Use when the user wants to find or resume a Zed/ACP thread.
allowed-tools: Bash(~/.claude/bin/claude-zed-threads:*), Read
argument-hint: "[project-dir]"
---

# Resume a Zed ACP thread

Zed's Claude client writes its threads into the same per-project store as the
terminal CLI, but as non-interactive (`operation: "enqueue"`) sessions. They
*do* appear in the built-in `/resume` picker, just mixed in with terminal
sessions and hard to pick out.

Zed/ACP threads for this project, newest first (each with the exact command to
reattach it):

!`~/.claude/bin/claude-zed-threads`

## Next step

A slash command runs inside *this* conversation and cannot reattach the CLI to
a different transcript. To fully resume one of the threads above:

- Run its `claude --resume <id>` line in your shell, or
- Use the `resume-zed` shell function to pick one interactively with `sk`.
  It reads only this project by default; `resume-zed --repo` spans every
  worktree of this repo and `resume-zed --all` spans every project.

If instead you'd rather continue that work **here**, without leaving this
session, tell me which thread and I'll read its transcript from
`~/.claude/projects/<slug>/<id>.jsonl` and pick up where it left off.
