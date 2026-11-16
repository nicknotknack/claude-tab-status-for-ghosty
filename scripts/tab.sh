#!/bin/bash
# ghostty-tab-status: put an emoji status in front of the terminal tab title.
# usage: tab.sh working|waiting|done|error|reset|start
#
# Prints ONLY a JSON object on stdout: Claude Code writes `terminalSequence`
# to the terminal itself (hooks have no TTY). Anything else printed on
# UserPromptSubmit would leak into the model's context.

state="$1"
input=$(cat)

# Inside our own background title generator: do nothing.
if [ "${GHOSTTY_TAB_STATUS_CHILD:-}" = 1 ]; then
  echo '{}'
  exit 0
fi

# --- read a top-level string field from the hook input (jq → plutil → none)
field() {
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$1" '.[$k] // empty' <<<"$input" 2>/dev/null
  elif command -v plutil >/dev/null 2>&1; then
    plutil -extract "$1" raw -o - - <<<"$input" 2>/dev/null
  fi
}

# --- JSON-escape a string (backslash, quote, control chars)
json_escape() {
  local s="$1" out="" c i code
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in
      '\') out+='\\' ;;
      '"') out+='\"' ;;
      *)
        printf -v code '%d' "'$c" 2>/dev/null
        if ((code >= 0 && code < 32)); then
          printf -v c '\\u%04x' "$code"
        fi
        out+="$c"
        ;;
    esac
  done
  printf '%s' "$out"
}

# --- tab name, first match wins:
#   1. the session name from /rename or --name (Claude Code sends it only on
#      SessionStart and UserPromptSubmit, so it's remembered per session)
#   2. a short title generated from the first prompt by a background Haiku call
#   3. the project folder name
sid=$(field session_id)
sid=${sid//[^A-Za-z0-9_-]/}
store="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/ghostty-tab-status}/names"
custom=$(field session_title)
name=""
if [ -n "$sid" ] && mkdir -p "$store" 2>/dev/null; then
  if [ "$state" = reset ]; then
    rm -f "$store/$sid".* 2>/dev/null
  else
    [ -n "$custom" ] && printf '%s' "$custom" >"$store/$sid.custom"
    name=$(cat "$store/$sid.custom" 2>/dev/null)
    [ -z "$name" ] && name=$(cat "$store/$sid.auto" 2>/dev/null)

    # First prompt of the session: generate a title in the background.
    prompt=$(field prompt)
    if [ -z "$name" ] && [ -n "$prompt" ] && [ ! -e "$store/$sid.pending" ] &&
      [ "${GHOSTTY_TAB_STATUS_AUTOTITLE:-1}" != 0 ] && command -v claude >/dev/null 2>&1; then
      : >"$store/$sid.pending"
      (
        export GHOSTTY_TAB_STATUS_CHILD=1 LC_ALL=en_US.UTF-8
        title=$(printf '%s' "${prompt:0:2000}" | claude -p --model haiku \
          --no-session-persistence --setting-sources "" --strict-mcp-config \
          --disable-slash-commands --tools "" \
          --system-prompt "You name terminal tabs. Reply with ONLY a short title (2-4 words, max 32 characters) describing the user's task, in the same language as the task. No quotes, no trailing punctuation, no emoji." 2>/dev/null)
        title=$(printf '%s' "$title" | tr -d '\000-\037"' | sed 's/^ *//; s/ *$//')
        title=${title:0:32}
        [ -n "$title" ] && printf '%s' "$title" >"$store/$sid.auto.tmp" &&
          mv "$store/$sid.auto.tmp" "$store/$sid.auto"
      ) </dev/null >/dev/null 2>&1 &
      disown 2>/dev/null
    fi
  fi
fi
if [ -z "$name" ]; then
  cwd=$(field cwd)
  name=$(basename "${cwd:-$PWD}")
fi
name=${name//[$'\001'-$'\037']/}   # never let control chars into the title

case "$state" in
  working) prefix="🟠 " ;;
  waiting) prefix="🔴 " ;;
  done | start) prefix="🟢 " ;;
  error)   prefix="❌ " ;;
  *)       prefix="" ;;
esac

if [ "$state" = reset ]; then
  seq=$'\e]2;\a'
else
  seq=$'\e]2;'"$prefix$name"$'\a'
fi

msg=""
if [ "$state" = start ] && [ "${CLAUDE_CODE_DISABLE_TERMINAL_TITLE:-}" != 1 ]; then
  msg="ghostty-tab-status: set CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 (see README) and restart claude, or Claude Code will overwrite the tab title."
fi

printf '{"terminalSequence":"%s"' "$(json_escape "$seq")"
[ -n "$msg" ] && printf ',"systemMessage":"%s"' "$(json_escape "$msg")"
printf '}\n'
