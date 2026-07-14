#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2025-2026 honeok <i@honeok.com>

set -eE

command clear

# mysql
# mysqldump -u root -p'8aDdVzUzXwjEAOhifFW6yg' --single-transaction --set-gtid-purged=OFF wordpress > ./wordpress.sql
# mysql -u root -p"8aDdVzUzXwjEAOhifFW6yg" -e "CREATE DATABASE IF NOT EXISTS wordpress;GRANT ALL PRIVILEGES ON wordpress.* TO 'honeok'@'%';FLUSH PRIVILEGES;"
if [ -d "$PWD/mysql/data" ]; then
    chown -R 1001:1001 "$PWD/mysql/data"
else
    mkdir -p "$PWD/mysql/data"
    chown -R 1001:1001 "$PWD/mysql/data"
fi
if [ -d "$PWD/mysql/logs" ]; then
    mkdir -p "$PWD/mysql/logs"
    chown -R 1001:1001 "$PWD/mysql/logs"
fi

# redis
if [ -d "$PWD/redis/data" ]; then
    chown -R 999:1000 "$PWD/redis/data"
fi

docker compose up -d
docker exec php sh -c "mkdir -p /run/php && chmod 777 /run/php"
docker exec php sh -c "sed -i '1i [global]\\ndaemonize = no' /usr/local/etc/php-fpm.d/www.conf"
docker exec php sh -c "sed -i '/^listen =/d' /usr/local/etc/php-fpm.d/www.conf"
docker exec php sh -c "echo -e '\nlisten = /run/php/php-fpm.sock\nlisten.owner = www-data\nlisten.group = www-data\nlisten.mode = 0777' >> /usr/local/etc/php-fpm.d/www.conf"
docker exec php sh -c "rm -f /usr/local/etc/php-fpm.d/zz-docker.conf"

docker exec redis redis-cli FLUSHALL > /dev/null 2>&1 || true
docker exec openresty chown -R nginx:nginx /usr/local/openresty/nginx/html > /dev/null 2>&1
docker exec php chown -R www-data:www-data /var/www/html > /dev/null 2>&1
docker compose restart openresty php

sleep 2
docker compose ps
