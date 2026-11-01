# infra-monitoring-project

Учебный DevOps-проект. 
Фичи: мониторинг доступности API, анализ логов, контейнеризация (Docker), CI/CD в github actions.

## Структура проекта

| Файл | Назначение |
| --- | --- |
| `check_api.sh` | Проверка доступности API по URL (код возврата 0 — доступен, 1 — нет) |
| `analyze_logs.sh` | Генерация тестового файла `access.log` (300+ строк) и его анализ: grep, awk, sed, sort, uniq |
| `docker-compose.yml` | `api` (hashicorp/http-echo) + `proxy` (nginx:alpine) во внутренней сети |
| `nginx.conf` | Конфиги, проксирование с порта 80 на `api:8080` |
| `.github/workflows/ci.yml` | CI: проверка синтаксиса и тесты скриптов при Pull Request |
| `traffic.pcapng` | Дамп HTTP-трафика из Wireshark |

## Требования

Linux (Ubuntu 22.04+), bash, curl, git, Docker.

## Запуск

### Мониторинг API

При ответе 200 скрипт выводит информацию, что API доступен и возвращает 0, если недоступен пишет API недоступен + код ответа: XXX и возвращает 1.

~~~bash
./check_api.sh https://httpbin.org/status/200
./check_api.sh https://httpbin.org/status/404
~~~

### Анализ логов

Без аргумента генерируется 300 строк, аргументом можно задать свой объём (не меньше 300).

~~~bash
./analyze_logs.sh
./analyze_logs.sh 1000
~~~

Скрипт выводит общее число запросов, топ-3 IP-адреса (извлекаются регулярным
выражением), количество ответов 4xx и 5xx и распределение по HTTP-методам.

### Docker Compose

Запуск, проверка ответа (ожидается «Monitoring Service Active»), статус контейнеров и остановка:

~~~bash
docker compose up -d
curl http://localhost:80
docker compose ps
docker compose down
~~~

Схема: клиент + `proxy` (nginx, порт 80) + `api` (http-echo, порт 8080).
Контейнеры связаны пользовательской через `monitoring-net`, nginx обращается к API по имени сервиса `api`.

## CI/CD

При создании Pull Request в `main` GitHub Actions выполняет:

1. `bash -n` для обоих скриптов (проверка синтаксиса);
2. `./check_api.sh https://httpbin.org/status/200` — ожидается код возврата 0;
3. проверку невалидного URL — ожидается код возврата 1;
4. запуск `analyze_logs.sh` и проверку, что в логе не меньше 300 строк;
5. валидацию `docker-compose.yml`.

## Безопасная передача проекта на сервер (SSH и SCP)

В примерах `deploy@203.0.113.10` — пользователь и IP удалённого сервера, замените на свои.

### 1. Генерация SSH-ключа

~~~bash
ssh-keygen -t ed25519 -C "deploy key" -f ~/.ssh/id_ed25519
~~~

Создаются два файла: приватный ключ `~/.ssh/id_ed25519` (никому не передаётся,
права 600) и публичный `~/.ssh/id_ed25519.pub`. Рекомендуется задать passphrase.

### 2. Копирование публичного ключа на сервер

~~~bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub deploy@203.0.113.10
ssh deploy@203.0.113.10 'echo "Вход по ключу работает"'
~~~

`ssh-copy-id` добавляет публичный ключ в `~/.ssh/authorized_keys` на сервере.
После проверки входа по ключу вход по паролю стоит отключить:
в `/etc/ssh/sshd_config` указать `PasswordAuthentication no` и выполнить
`sudo systemctl restart ssh`.

Для удобства можно добавить в `~/.ssh/config`:

~~~
Host monitoring
    HostName 203.0.113.10
    User deploy
    IdentityFile ~/.ssh/id_ed25519
~~~

После этого достаточно `ssh monitoring` и `scp файл monitoring:~/`.

### 3. Передача архива через scp

Проект упаковывается без `.git` и логов, для архива считается контрольная сумма,
затем архив копируется на сервер, проверяется и распаковывается.

~~~bash
tar --exclude='.git' --exclude='*.log' -czf /tmp/infra-monitoring-project.tar.gz \
    -C ~ infra-monitoring-project
sha256sum /tmp/infra-monitoring-project.tar.gz
scp /tmp/infra-monitoring-project.tar.gz deploy@203.0.113.10:~/
ssh deploy@203.0.113.10 'sha256sum ~/infra-monitoring-project.tar.gz \
    && tar -xzf ~/infra-monitoring-project.tar.gz -C ~ \
    && rm ~/infra-monitoring-project.tar.gz'
~~~

### 4. Передача через tar + ssh (без промежуточного файла)

~~~bash
tar --exclude='.git' --exclude='*.log' -czf - -C ~ infra-monitoring-project \
    | ssh deploy@203.0.113.10 'tar -xzf - -C ~'
~~~

Архив упаковывается на лету и распаковывается на сервере, весь поток зашифрован SSH.

### 5. Пример деплоя

Доставка файлов, обновление образов и перезапуск стека, проверка сервиса:

~~~bash
SERVER=deploy@203.0.113.10
tar --exclude='.git' --exclude='*.log' -czf - -C ~ infra-monitoring-project \
    | ssh "$SERVER" 'tar -xzf - -C ~'
ssh "$SERVER" 'cd ~/infra-monitoring-project && docker compose pull && docker compose up -d'
ssh "$SERVER" 'cd ~/infra-monitoring-project && docker compose ps && ./check_api.sh http://localhost:80'
~~~

## Анализ сетевого трафика

Дамп `traffic.pcapng` можно открыть в Wireshark и применить фильтр `http`.
Описание участников обмена, методов и кодов ответов приложено в отчете.
