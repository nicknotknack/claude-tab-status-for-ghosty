---
name: remove
description: Undo /ghostty-tab-status:setup — give the tab title back to Claude Code. Run before uninstalling the plugin.
disable-model-invocation: true
---

Edit the user's `~/.claude/settings.json`:

- Remove the `"CLAUDE_CODE_DISABLE_TERMINAL_TITLE"` key from the top-level `"env"` object. If `"env"` is then empty, remove `"env"` too.
- Keep every other key and value exactly as it is.
- If the key isn't there, change nothing.

Then tell the user in one short line, in their language: done; to finish, run `/plugin uninstall ghostty-tab-status@nicknotknack` and restart `claude`.
