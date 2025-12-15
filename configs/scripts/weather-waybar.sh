#!/usr/bin/env bash
set -euo pipefail

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-weather.json"
MAX_AGE=900
API_URL="https://wttr.in/?format=j1"

now=$(date +%s)
if [ -f "$CACHE" ]; then
  modified=$(stat -c %Y "$CACHE" 2>/dev/null || echo 0)
  if [ $(( now - modified )) -lt $MAX_AGE ]; then
    if python - <<'PY2'
import json, sys
try:
    json.load(open(sys.argv[1], 'r'))
except Exception:
    raise SystemExit(1)
PY2
 "$CACHE"; then
      cat "$CACHE"
      exit 0
    fi
  fi
fi

fetch_weather() {
  local data
  if ! data=$(curl -fsSL --max-time 5 "$API_URL"); then
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1 || ! command -v python >/dev/null 2>&1; then
    return 2
  fi

  local city condition temp feels humidity wind
  city=$(printf '%s' "$data" | jq -r '.nearest_area[0].areaName[0].value')
  condition=$(printf '%s' "$data" | jq -r '.current_condition[0].weatherDesc[0].value')
  temp=$(printf '%s' "$data" | jq -r '.current_condition[0].temp_C')
  feels=$(printf '%s' "$data" | jq -r '.current_condition[0].FeelsLikeC')
  humidity=$(printf '%s' "$data" | jq -r '.current_condition[0].humidity')
  wind=$(printf '%s' "$data" | jq -r '.current_condition[0].windspeedKmph')

  TEXT_VALUE="$city $temp°C"
  TOOLTIP_VALUE="$condition
Feels like: $feels°C
Humidity: $humidity%
Wind: $wind km/h"

  TEXT="$TEXT_VALUE" TOOLTIP="$TOOLTIP_VALUE" python - <<'PY'
import json, os
text = os.environ.get("TEXT", "Weather")
tooltip = os.environ.get("TOOLTIP", "")
print(json.dumps({"text": text, "tooltip": tooltip}))
PY
}

if output=$(fetch_weather); then
  printf '%s' "$output" >"$CACHE"
  printf '%s' "$output"
else
  if [ -f "$CACHE" ]; then
    cat "$CACHE"
  else
    printf '{"text":"Weather","tooltip":"Unavailable"}'
  fi
fi
