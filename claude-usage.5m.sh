#!/bin/bash

# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>

API_URL="https://api.anthropic.com/api/oauth/usage"
BETA_HEADER="oauth-2025-04-20"

# Get OAuth token from macOS Keychain (Claude Code stores credentials there)
CREDS_JSON=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
TOKEN=""
if [ -n "$CREDS_JSON" ]; then
    TOKEN=$(echo "$CREDS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('claudeAiOauth',{}).get('accessToken',''))" 2>/dev/null)
fi

if [ -z "$TOKEN" ]; then
    echo "CC: ? | sfSymbol=brain.head.profile"
    echo "---"
    echo "No OAuth token found | color=red"
    echo "Log in to Claude Code first | size=12"
    echo "---"
    echo "Refresh | refresh=true"
    exit 0
fi

# Fetch usage data to temp file
TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

HTTP_CODE=$(curl -s -o "$TMPFILE" --max-time 10 -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    -H "anthropic-beta: $BETA_HEADER" \
    -H "Accept: application/json" \
    "$API_URL" 2>/dev/null)

FETCH_TIME=$(date +"%H:%M:%S")

if [ "$HTTP_CODE" = "000" ] || [ ! -s "$TMPFILE" ]; then
    echo "CC: err | sfSymbol=brain.head.profile"
    echo "---"
    echo "Network error | color=red"
    echo "---"
    echo "Refresh | refresh=true"
    exit 0
elif [ "$HTTP_CODE" != "200" ]; then
    ERR_MSG=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); e=d.get('error',{}); print(e.get('message','') if isinstance(e,dict) else str(e))" "$TMPFILE" 2>/dev/null)
    echo "CC: err | sfSymbol=brain.head.profile"
    echo "---"
    echo "API error (HTTP $HTTP_CODE) | color=red"
    if [ -n "$ERR_MSG" ]; then
        echo "$ERR_MSG | size=12"
    fi
    echo "---"
    echo "Refresh | refresh=true"
    exit 0
fi

# Parse with python3 (always available on macOS)
PARSED=$(python3 - "$TMPFILE" << 'PYEOF'
import json, sys
from datetime import datetime, timezone

def time_until(iso_str):
    if not iso_str or iso_str in ("null", "None"):
        return ""
    try:
        target = datetime.fromisoformat(iso_str)
        now = datetime.now(timezone.utc)
        total_min = max(0, int((target - now).total_seconds() / 60))
        days = total_min // 1440
        hours = (total_min % 1440) // 60
        mins = total_min % 60
        if days > 0:
            return f"{days}d{hours}h"
        elif hours > 0:
            return f"{hours}h{mins}m"
        else:
            return f"{mins}m"
    except:
        return ""

try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
except:
    print("? ? ? ? ? ? false ? ? ?")
    sys.exit(0)

fh = d.get("five_hour") or {}
sd = d.get("seven_day") or {}
sn = d.get("seven_day_sonnet") or {}
xu = d.get("extra_usage") or {}

def pct(d, key="utilization"):
    v = d.get(key)
    return int(v) if v is not None else "?"

session_pct = pct(fh)
session_reset = time_until(fh.get("resets_at"))
weekly_pct = pct(sd)
weekly_reset = time_until(sd.get("resets_at"))
sonnet_pct = pct(sn)
sonnet_reset = time_until(sn.get("resets_at"))
extra_enabled = str(xu.get("is_enabled", False)).lower()
extra_pct = pct(xu)
extra_used = f'{xu["used_credits"] / 100:.2f}' if xu.get("used_credits") is not None else "?"
extra_limit = f'{int(xu["monthly_limit"] / 100)}' if xu.get("monthly_limit") is not None else "?"

print(f'{session_pct} {session_reset or "-"} {weekly_pct} {weekly_reset or "-"} {sonnet_pct} {sonnet_reset or "-"} {extra_enabled} {extra_pct} {extra_used} {extra_limit}')
PYEOF
)

read -r SESSION_PCT SESSION_RESET WEEKLY_PCT WEEKLY_RESET SONNET_PCT SONNET_RESET EXTRA_ENABLED EXTRA_PCT EXTRA_USED EXTRA_LIMIT <<< "$PARSED"

# Fallback if parsing failed
if [ -z "$SESSION_PCT" ]; then
    echo "CC: ? | sfSymbol=brain.head.profile"
    echo "---"
    echo "Failed to parse API response | color=red"
    echo "---"
    echo "Refresh | refresh=true"
    exit 0
fi

# Menu bar title
echo "CC: ${SESSION_PCT}% | sfSymbol=brain.head.profile"
echo "---"

# 5-hour session
echo "5-Hour Session | size=14"
echo "Usage: ${SESSION_PCT}% | font=SFMono-Regular"
if [ "$SESSION_RESET" != "-" ]; then
    echo "Resets in: $SESSION_RESET | font=SFMono-Regular"
fi
echo "---"

# Weekly usage
echo "Weekly (All Models) | size=14"
echo "Usage: ${WEEKLY_PCT}% | font=SFMono-Regular"
if [ "$WEEKLY_RESET" != "-" ]; then
    echo "Resets in: $WEEKLY_RESET | font=SFMono-Regular"
fi

# Sonnet weekly (if available)
if [ "$SONNET_PCT" != "?" ] && [ -n "$SONNET_PCT" ]; then
    echo "---"
    echo "Weekly (Sonnet) | size=14"
    echo "Usage: ${SONNET_PCT}% | font=SFMono-Regular"
    if [ "$SONNET_RESET" != "-" ]; then
        echo "Resets in: $SONNET_RESET | font=SFMono-Regular"
    fi
fi

# Extra usage (if enabled)
if [ "$EXTRA_ENABLED" = "true" ]; then
    echo "---"
    echo "Extra Usage | size=14"
    echo "Usage: ${EXTRA_PCT}% (\$${EXTRA_USED}/\$${EXTRA_LIMIT}) | font=SFMono-Regular"
fi

echo "---"
echo "Open Usage Dashboard | href=https://claude.ai/settings/usage"
echo "Refresh | refresh=true"
echo "---"
echo "Last fetch: $FETCH_TIME (HTTP $HTTP_CODE) | size=10 color=gray"
