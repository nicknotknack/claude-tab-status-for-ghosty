---
name: setup
description: Turn off Claude Code's built-in terminal title so ghostty-tab-status can show 🟠/🔴/🟢 in the tab. Run once after installing the plugin.
disable-model-invocation: true
---

Edit the user's `~/.claude/settings.json` (create it as `{}` if missing):

- Add `"CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1"` inside the top-level `"env"` object, creating `"env"` if absent.
- Keep every other key and value exactly as it is. Don't touch `hooks`.
- If the key is already `"1"`, change nothing.

Then tell the user in one short line, in their language: done, restart `claude` in each tab for the status to appear; before uninstalling the plugin run `/ghostty-tab-status:remove`.
