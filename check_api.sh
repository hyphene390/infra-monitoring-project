#!/usr/bin/env bash

set -u

if [ "$#" -ne 1 ]; then
    echo "Использование: $0 <URL>" >&2
    exit 1
fi

URL="$1"

if ! [[ "$URL" =~ ^https?://[^[:space:]]+$ ]]; then
    echo "Ошибка: '$URL' не похож на URL (нужен http:// или https://)" >&2
    exit 1
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 10 --retry 3 --retry-delay 2 "$URL")

if [ "$HTTP_CODE" = "200" ]; then
    echo "API доступен"
    exit 0
else
    echo "API недоступен, код ответа: $HTTP_CODE"
    exit 1
fi
