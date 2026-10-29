#!/usr/bin/env bash

set -euo pipefail

LOG_FILE="access.log"
LINES="${1:-300}"

if ! [[ "$LINES" =~ ^[0-9]+$ ]] || [ "$LINES" -lt 300 ]; then
    echo "Ошибка: количество строк должно быть числом не меньше 300" >&2
    exit 1
fi

IPS=("192.168.1.10" "192.168.1.15" "10.0.0.5" "10.0.0.23" "172.16.0.4" "203.0.113.7" "198.51.100.42")
METHODS=("GET" "GET" "GET" "POST" "PUT" "DELETE")
PATHS=("/api/users" "/api/login" "/api/orders" "/api/products" "/api/status" "/api/logout")
CODES=(200 200 200 200 201 301 400 401 403 404 500 502 503)

START=$(( 10 * 3600 + 15 * 60 ))

for (( i = 0; i < LINES; i++ )); do
    if (( RANDOM % 3 == 0 )); then
        ip=${IPS[RANDOM % 2]}
    else
        ip=${IPS[RANDOM % ${#IPS[@]}]}
    fi
    method=${METHODS[RANDOM % ${#METHODS[@]}]}
    path=${PATHS[RANDOM % ${#PATHS[@]}]}
    code=${CODES[RANDOM % ${#CODES[@]}]}
    t=$(( START + i ))
    printf '%s - - [15/Aug/2026:%02d:%02d:%02d] "%s %s HTTP/1.1" %s\n' \
        "$ip" $(( t / 3600 % 24 )) $(( t / 60 % 60 )) $(( t % 60 )) \
        "$method" "$path" "$code"
done > "$LOG_FILE"

echo "Сгенерирован файл $LOG_FILE ($(wc -l < "$LOG_FILE") строк)"
echo

IP_REGEX='^([0-9]{1,3}\.){3}[0-9]{1,3}'

echo "===== Анализ $LOG_FILE ====="

TOTAL=$(grep -cE "$IP_REGEX" "$LOG_FILE")
echo "Общее количество запросов: $TOTAL"
echo

echo "Топ-3 IP-адреса по числу запросов:"
grep -oE "$IP_REGEX" "$LOG_FILE" \
    | sort | uniq -c | sort -rn | head -n 3 \
    | awk '{ printf "  %d. %-15s — %d запросов\n", NR, $2, $1 }'
echo

echo "Ошибки по кодам ответа:"
awk '$NF ~ /^4[0-9][0-9]$/ { c4++ }
     $NF ~ /^5[0-9][0-9]$/ { c5++ }
     END { printf "  4xx (ошибки клиента): %d\n  5xx (ошибки сервера): %d\n", c4, c5 }' "$LOG_FILE"
echo

echo "Запросы по HTTP-методам:"
sed -E 's/.*"([A-Z]+) .*/\1/' "$LOG_FILE" \
    | sort | uniq -c | sort -rn \
    | awk '{ printf "  %-7s %d\n", $2, $1 }'
