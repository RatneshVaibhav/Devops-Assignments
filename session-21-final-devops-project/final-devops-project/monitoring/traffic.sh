#!/usr/bin/env bash
# traffic.sh [seconds] [workers] - mixed traffic against the ShelfShare API through the ingress:
# searches and stats (200), unknown books (404), listings that are created, reserved and
# deleted again (201/200/204), so every panel of the Grafana dashboard has data.
set -u
BASE="${BASE:-http://shelfshare.localhost:8088}"
DURATION="${1:-120}"; WORKERS="${2:-2}"
JSON=(-H "Content-Type: application/json")

worker() {
  local w=$1 n=0 end=$((SECONDS + DURATION)) id
  while [ $SECONDS -lt $end ]; do
    curl -s -o /dev/null "$BASE/api/books"
    curl -s -o /dev/null "$BASE/api/books/stats"
    curl -s -o /dev/null "$BASE/api/books?status=available&q=data"
    curl -s -o /dev/null "$BASE/api/books/999999"
    if (( n % 10 == 0 )); then
      id=$(curl -s "${JSON[@]}" -X POST "$BASE/api/books" \
        -d "{\"title\":\"Traffic test $w-$n\",\"author\":\"Load Generator\",\"course_code\":\"CS301\",\"owner_name\":\"traffic.sh\"}" | jq -r .id)
      curl -s -o /dev/null "${JSON[@]}" -X POST "$BASE/api/books/$id/reserve" -d '{"reserved_by":"traffic.sh"}'
      curl -s -o /dev/null -X DELETE "$BASE/api/books/$id"
    fi
    n=$((n + 1))
  done
  echo "worker $w: $((n * 4 + (n + 9) / 10 * 3)) requests"
}

for w in $(seq 1 "$WORKERS"); do worker "$w" & done
wait
