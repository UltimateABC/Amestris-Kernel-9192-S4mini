#!/bin/sh
echo "XM Script Version 2.2 , Wait 5 Seconds..."

sleep 5

get_cpu_temp() {
	cpu_temp=$(</sys/class/thermal/thermal_zone0/temp)
	cpu_temp=$((cpu_temp/1000)) # Convert to Celsius
	#echo "$cpu_temp"
}

FREERMO=$(free -h | grep 'Mem' | awk '{print $7}')


if [[ $FREERMO == *M ]]; then
	FREERM=${FREERMO//M/}
	FREERM=$(echo $FREERM | xargs)
fi


if [[ $FREERMO == *G ]]; then
	FREERM=${FREERMO//G/}
	FREERM=$(echo $FREERM | xargs)
	FREERM=$(echo "$FREERM * 1000" | bc)
fi

kill_xmrig() {
	#echo "Killing xmrig..."
	killall -9 xmrig
	#echo "Miner has been stopped."
}

start_xmrig() {
	#echo "Starting xmrig..."
	bash /root/xinixzph.sh </dev/null &>/dev/null &
}

xrig=$(pgrep -cx xmrig)

#echo "XRIG Running Proxy=$xrig"

CPUTEMP=$(get_cpu_temp)

#echo "CPU Temprature =$CPUTEMP"
#echo "Available Ram  =$FREERM"
#echo
	
if [ "$xrig" -eq 1 ]; then
	#echo "Miner is currently running..."
	
	if [ "$CPUTEMP" -gt 75 ]; then
		#echo "   - High CPU Temp, Exiting..."
		kill_xmrig
	fi

	if (( $(echo "$FREERM < 300" | bc -l) )); then
		#echo "   - Not enough RAM, Exiting..."
		kill_xmrig
	fi
	
elif [ "$xrig" -gt 1 ]; then
	#echo "Miner is running more than usual..."
	kill_xmrig
	sleep 2
	start_xmrig

elif [ "$xrig" -eq 0 ]; then
	echo "Miner is not running..."
	echo "Temp= $CPUTEMP"
	echo "FREERM= $FREERM"

	if [ "$CPUTEMP" -lt 60 ]; then
		echo "CPU Temprature is OK : $CPUTEMP"
		
		if (( $(echo "$FREERM > 2500" | bc -l) )); then
			echo "Available Ram is OK : $FREERM"        
			start_xmrig
		else
			echo "Available Ram is not OK : $FREERM"
			echo "Conditions not met to start the miner."
		fi
	else
        	echo "CPU Temprature is not OK : $CPUTEMP"
		echo "Conditions not met to start the miner."
	fi
fi
