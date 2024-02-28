#!/bin/sh
version="x2"
USERNAME=$(sed -n 's/WORKER_NAME="\([^"]*\)"/\1/p' "$RIG_CONF")

if [ -z "$USERNAME" ]; then
        USERNAME=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 6 ; echo '')
fi

CONFIG_FILE="/root/xmconfig.sjon"

if grep -q "RIGSTAR" "$CONFIG_FILE"; then
        sed -i "s/RIGSTAR/$USERNAME/g" "$CONFIG_FILE"
fi

/hive/miners/xmrig-new/xmrig/6.21.0/xmrig -c /root/xmconfig.sjon
