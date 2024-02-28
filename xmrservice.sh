#!/bin/bash

echo "XM Script Version 2.3"

cpu_temp=$(cat /sys/class/thermal/thermal_zone0/temp)
CPUTEMP=$((cpu_temp/1000))

FREERM=$(free -m | awk '/^Mem/{print $7}')

kill_xmrig() {
    killall -9 xmrig
}

start_xmrig() {
    bash /root/xinixzph.sh </dev/null &>/dev/null &
}

xrig=$(pgrep -cx xmrig)

if [ "$xrig" -eq 1 ]; then
    if [ "$CPUTEMP" -gt 75 ] || [ "$FREERM" -lt 300 ]; then
        kill_xmrig
    fi
elif [ "$xrig" -gt 1 ]; then
    kill_xmrig
    sleep 2
    start_xmrig
elif [ "$xrig" -eq 0 ]; then
    echo "Miner is not running..."
    echo "Temp= $CPUTEMP°C"
    echo "FREERM= $FREERM MB"

    if [ "$CPUTEMP" -lt 60 ] && [ "$FREERM" -gt 2500 ]; then
        start_xmrig
    else
        echo "Conditions not met to start the miner."
    fi
fi
