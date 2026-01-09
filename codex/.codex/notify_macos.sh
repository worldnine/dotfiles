#!/bin/bash
# ~/.codex/notify_macos.sh

LAST_MESSAGE=$(echo "$1" | jq -r '.["last-assistant-message"] // "Codex task completed"')

/usr/bin/osascript - "$LAST_MESSAGE" <<'APPLESCRIPT'
on run argv
  set msg to item 1 of argv
  display notification msg with title "Codex"
end run
APPLESCRIPT
