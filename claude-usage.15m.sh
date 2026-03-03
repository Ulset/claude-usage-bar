#!/bin/bash

# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>

HISTORY_FILE="$HOME/.claude/history.jsonl"
STATS_FILE="$HOME/.claude/stats-cache.json"

TODAY=$(date +%Y-%m-%d)
TODAY_TS_START=$(date -j -f "%Y-%m-%d %H:%M:%S" "$TODAY 00:00:00" +%s 2>/dev/null)
TODAY_TS_START_MS=$((TODAY_TS_START * 1000))

# Count today's messages and sessions from history.jsonl
if [ -f "$HISTORY_FILE" ]; then
    read -r MSG_COUNT SESSION_COUNT <<< $(python3 -c "
import json, sys

today_start_ms = $TODAY_TS_START_MS
sessions = set()
msg_count = 0

with open('$HISTORY_FILE', 'r') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
            ts = d.get('timestamp', 0)
            if ts >= today_start_ms:
                msg_count += 1
                sid = d.get('sessionId', '')
                if sid:
                    sessions.add(sid)
        except:
            pass

print(f'{msg_count} {len(sessions)}')
" 2>/dev/null)
else
    MSG_COUNT=0
    SESSION_COUNT=0
fi

# Get all-time stats from stats-cache
if [ -f "$STATS_FILE" ]; then
    read -r TOTAL_SESSIONS TOTAL_MESSAGES <<< $(python3 -c "
import json
with open('$STATS_FILE') as f:
    d = json.load(f)
print(d.get('totalSessions', 0), d.get('totalMessages', 0))
" 2>/dev/null)
else
    TOTAL_SESSIONS=0
    TOTAL_MESSAGES=0
fi

# Menu bar title
if [ "$MSG_COUNT" = "0" ] || [ -z "$MSG_COUNT" ]; then
    MSG_COUNT=0
fi
if [ "$SESSION_COUNT" = "0" ] || [ -z "$SESSION_COUNT" ]; then
    SESSION_COUNT=0
fi

echo "CC: ${MSG_COUNT}msg | sfSymbol=brain.head.profile"
echo "---"
echo "Today ($TODAY) | size=14"
echo "Messages: $MSG_COUNT | font=SF Mono"
echo "Sessions: $SESSION_COUNT | font=SF Mono"
echo "---"
echo "All Time | size=14"
echo "Total Sessions: ${TOTAL_SESSIONS:-?} | font=SF Mono"
echo "Total Messages: ${TOTAL_MESSAGES:-?} | font=SF Mono"
echo "---"
echo "Open Usage Dashboard | href=https://console.anthropic.com/settings/usage"
echo "Refresh | refresh=true"
