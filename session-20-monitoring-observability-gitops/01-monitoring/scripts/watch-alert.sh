#!/usr/bin/env bash
# watch-alert.sh <alertname> [timeout-seconds]
# Polls the Prometheus API every 10 s and prints the alert's state whenever it changes
# (inactive -> pending -> firing), together with the value that triggered it.
set -uo pipefail
NAME="$1"; TIMEOUT="${2:-360}"; PROM="${PROM:-http://prometheus.localhost:8088}"
last=""; start=$(date +%s)
while :; do
  json=$(curl -s "$PROM/api/v1/rules?type=alert")
  state=$(jq -r --arg n "$NAME" '[.data.groups[].rules[] | select(.name==$n)][0].state' <<<"$json")
  value=$(jq -r --arg n "$NAME" '[.data.groups[].rules[] | select(.name==$n) | .alerts[]?.value][0] // "-"' <<<"$json")
  if [ "$state" != "$last" ]; then
    printf '%s  +%3ss  %-28s %-9s value=%s\n' "$(date +%T)" "$(( $(date +%s) - start ))" "$NAME" "$state" "$value"
    last="$state"
  fi
  [ "$state" = "firing" ] && exit 0
  [ $(( $(date +%s) - start )) -ge "$TIMEOUT" ] && { echo "timed out (state=$state)"; exit 1; }
  sleep 10
done
