#!/bin/sh
version="x2"

USERNAME=$(sed -n 's/WORKER_NAME="\([^"]*\)"/\1/p' "$RIG_CONF")

if [ -z "$USERNAME" ]; then
	USERNAME=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 6 ; echo '')
fi

/hive/miners/xmrig-new/xmrig/6.21.0/xmrig -c /root/xmconfig.sjon --pass=$USERNAME

#/hive/miners/xmrig-new/xmrig/6.21.0/xmrig -c /root/xmconfig.sjon --background --pass=$USERNAME --rig-id=$USERNAME
