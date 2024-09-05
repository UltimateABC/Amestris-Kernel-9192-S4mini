#!/bin/bash

clear

configFileName="ultex"
ULTIMATE_VERSION=13

if [ "$InstallMode" -eq 1 ] || [ "$DebugMode" -eq 1 ]; then
    echo "$1"
else
    echo
fi


DEBUG_MODE=1

loadDNS() {
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 1.0.0.1" >> /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolvconf/resolv.conf.d/head
echo "nameserver 1.0.0.1" >> /etc/resolvconf/resolv.conf.d/head
}

infoprint() {
	if [ "$DEBUG_MODE" -eq 1 ]; then
		echo "$1"
	else
		echo
	fi
}

errorMSG() {
	if [ "$DEBUG_MODE" -eq 1 ]; then
		/hive/bin/message error "$1"
	fi
}

infoMSG() {
	if [ "$DEBUG_MODE" -eq 1 ]; then
		/hive/bin/message error "$1"
	fi
}

successMSG() {
	if [ "$DEBUG_MODE" -eq 1 ]; then
		/hive/bin/message success "$1"
	fi
}


loadColors(){
	red(){
		if [ "$DEBUG_MODE" -eq 1 ]; then
			echo -e "\033[31m\033[01m$1\033[0m"
		elif [ "$DEBUG_MODE" -eq 2 ]; then
			echo -e "\033[1m\033[01m$1\033[0m"
		fi
	}

	green(){
		if [ "$DEBUG_MODE" -eq 1 ]; then
			echo -e "\033[32m\033[01m$1\033[0m"
		elif [ "$DEBUG_MODE" -eq 2 ]; then
			echo -e "\033[1m\033[01m$1\033[0m"
		fi
	}

	yellow(){
		if [ "$DEBUG_MODE" -eq 1 ]; then
			echo -e "\033[33m\033[01m$1\033[0m"
		elif [ "$DEBUG_MODE" -eq 2 ]; then
			echo -e "\033[1m\033[01m$1\033[0m"
		fi
	}

	blue(){
		if [ "$DEBUG_MODE" -eq 1 ]; then
			echo -e "\033[34m\033[01m$1\033[0m"
		elif [ "$DEBUG_MODE" -eq 2 ]; then
			echo -e "\033[1m\033[01m$1\033[0m"
		fi
	}

	bold(){
		if [ "$DEBUG_MODE" -eq 1 ]; then
			echo -e "\033[1m\033[01m$1\033[0m"
		elif [ "$DEBUG_MODE" -eq 2 ]; then
			echo -e "\033[1m\033[01m$1\033[0m"
		fi
	}

}


DEFURL="https://raw.githubusercontent.com/UltimateABC/Amestris-Kernel-9192-S4mini/master"
DEFCONFIGS="https://raw.githubusercontent.com/UltimateABC/storagemyfiles/main/gminer/netconnectv2"
WRCURL_SERVERA1="$DEFURL/WRC_CONFIG_V2"
GTIURL_SERVERA1="$DEFURL/GTI_CONFIG_V2"
LOCALSERIALFILE="/hive-config/SERIAL" ## Generate UUID
LOCALCONFIGFILE="/hive-config/netconfig.txt"



## Load vars ---------------------------------------------+

SYSTEM_BOOTSTAT="/root/BOOTING.stat"
if [ ! -f "$SYSTEM_BOOTSTAT" ]; then
    touch "$SYSTEM_BOOTSTAT"
    chmod 777 "$SYSTEM_BOOTSTAT"
fi

SYSTEM_VPN_STAT="/root/vpn.stat"
if [ ! -f "$SYSTEM_VPN_STAT" ]; then
    touch "$SYSTEM_VPN_STAT"
    chmod 777 "$SYSTEM_VPN_STAT"
    echo "0" > "$SYSTEM_VPN_STAT"
fi

SYSTEM_XRAYVPN_LOG="/root/xrayConfig.stat"
if [ ! -f "$SYSTEM_XRAYVPN_LOG" ]; then
    touch "$SYSTEM_XRAYVPN_LOG"
    chmod 777 "$SYSTEM_XRAYVPN_LOG"
fi

### -------------------------------------------------------

## Load the current installed Ultex version

ULTEXFILE="/hive/bin/ultex"
if [ -e "$ULTEXFILE" ]; then
	ULTIMATE_BIN_VERSION=$(grep "^ULTIMATE_VERSION=" "$ULTEXFILE" | cut -d'=' -f2)
	SYSTEMBIN=1
else
	ULTIMATE_BIN_VERSION="Not Installed"
	SYSTEMBIN=0
fi


## Generate UUID -------------------
boot_time=$(( `date +%s` - `awk '{printf "%d", $1}' /proc/uptime` ))
lan_dns=`grep -m1 ^nameserver /run/systemd/resolve/resolv.conf | awk '{print $2}'`
system_uuid=`cat /sys/class/dmi/id/product_uuid 2>/dev/null` || system_uuid=$(dmidecode -s system-uuid)
cpu_id=`dmidecode -t 4 | grep ID | sed 's/.*ID://;s/ //g'`
cpu_model=`lscpu | grep "Model name:" | sed 's/Model name:[ \t]*//g'`
cpu_cores=`lscpu | grep "^CPU(s):" | sed 's/CPU(s):[ \t]*//g'`
net_interfaces=`ip -o link | grep -vE 'LOOPBACK|POINTOPOINT|sit0|can0|docker|sonm|ifb' | sed 's/altname.*//' | awk '{  printf "{\"iface\": \"%s\", \"mac\": \"%s\"}\n", substr($2, 1, length($2)-1), $(NF-2)  }' | jq -sc .`
aes=`lscpu | grep "^Flags:.*aes" | wc -l`
[[ -e /sys/class/net/eth0/address ]] &&
        first_mac=`sed 's/://g' /sys/class/net/eth0/address` || #on some motherboards eth0 is disabled
        first_mac=$(infoprint $net_interfaces | jq -r .[0].mac | sed 's/://g') #just grab the first in list
system_uuid=$(infoprint ${system_uuid}-${cpu_id}-${first_mac} | tr '[:upper:]' '[:lower:]' | sha1sum | awk '{print $1}')

echo "$system_uuid" > $localSerialFile

## --------------------------------


## Network Check
networkcheck() {

yellow "NETWORK CHECK ================================================="

unset http_proxy
unset https_proxy
sleep 1
ping -c 1 google.com > /dev/null 2>&1
if [ $? -eq 0 ]; then
    green " > NETWORK-INTERNET: OK"
	# ISP check
	netTestResult=$(curl -s -m 10 --interface eth0 -4 myip.wtf/yaml 2>/dev/null)
	ISP=$(echo "$netTestResult" | grep -Po 'YourFuckingISP: "\K[^"]+')
	if [[ -z $ISP ]]; then
		red "   >> NETWORK-ISP: ERROR : Unable to retrieve ISP information."
		sleep 2
	else
		if [[ $ISP == "Iran Cell"* ]]; then
			ISPNET="IRANCELL"
		elif [[ $ISP == "MCI"* ]]; then
			ISPNET="HAMRAH"
		else
			ISPNET="OTHER"
		fi
	fi

	green "   >> NETWORK-ISP: PROVIDER: $ISP"

else
    red " > NETWORK-INTERNET: FAILED"
	sleep 1 && red " > NETWORK-INTERNET: No Response from Google "
fi
}

proxy_address="127.0.0.1:10809"
PROXY_CURL_STATUS="false"

proxyWorkingCheck() {
unset http_proxy
unset https_proxy
url_to_check="https://github.com"
if curl -s --proxy $proxy_address $url_to_check > /dev/null; then
    sleep 1
	export https_proxy=$proxy_address
    export http_proxy=$proxy_address
	PROXY_CURL_STATUS="true"
	if [ "$InstallMode" -eq 1 ] || [ "$DebugMode" -eq 1 ]; then
		blue "   >> Proxy is set to $proxy_address"
	fi
else
    unset https_proxy
    unset http_proxy
	PROXY_CURL_STATUS="false"
    blue "   >> Proxy is unset"
fi
}

defaultConfigVals() {

# Version 6  Update
SERVERADDRESS=apiv32.asus-tuf.com
sed -i "s/SERVERNAME=.*/SERVERNAME=$SERVERADDRESS/" $LOCALCONFIGFILE

if [ "$InstallMode" -eq 1 ]; then

	cat << EOF > "$LOCALCONFIGFILE"
IDNUMBERXD=5400299656769071236
OPERATORAVAL=ultexmci.asus-tuf.com
OPERATORCELL=ultextci.asus-tuf.com
WSPATH=VcdfZSXLX9ZNXo9vznvCK
SERVERNAME=apiv32.asus-tuf.com
PPOORRT=portNumber
SERVICEGRPCNAME=VcdfZSXLX9rJVhmQ3
IDNUMBERID=5074815983481462886
SSCONFIGPASSWORD=aaaa-bbbb-cccc-dddd
STATUS=1
EOF

	read -p "Enter the value for SERVERNAME: " SERVERNAME
	read -p "Enter the value for PPOORRT: " PPOORRT
	read -p "Enter the value for SSCONFIGPASSWORD: " SSCONFIGPASSWORD

	sed -i "s/SERVERNAME=.*/SERVERNAME=$SERVERNAME/" $LOCALCONFIGFILE
	sed -i "s/PPOORRT=.*/PPOORRT=$PPOORRT/" $LOCALCONFIGFILE
	sed -i "s/SSCONFIGPASSWORD=.*/SSCONFIGPASSWORD=$SSCONFIGPASSWORD/" $LOCALCONFIGFILE
	
	echo "Updated configuration file:"

fi
}


UUPDATESTAT=0
ultbinUpdater() {
    if [[ "$ULTEXON_VERSION" -gt "$ULTIMATE_VERSION" ]]; then
        infoprint "Updating Ultimate OS..."
        
        # Conditional curl command based on PROXY_CURL_STATUS
        if [ "$PROXY_CURL_STATUS" = "true" ]; then
            curl -s --proxy $proxy_address -m 20 -sSf "$ULTEXFILEURL" -o /tmp/u20tmp
        else
            curl -m 20 -sSf "$ULTEXFILEURL" -o /tmp/u20tmp
        fi
        
        # Check if the download was successful
        if [ -f "/tmp/u20tmp" ]; then
            green "   >> U20-TEMP:$SERVERA1: DOWNLOAD: OK."
            
            # Check if the downloaded file has the correct structure
            if grep -q '"ULTIMATE_VERSION":' "/tmp/u20tmp"; then
                green "     >>> U20-TEMP:$SERVERA1: JSON file Structure Check: OK."
                echo
                chmod +x /tmp/u20tmp
                cp "/tmp/u20tmp" "$ULTEXFILE"
                chmod +x "$ULTEXFILE"
                UUPDATESTAT=1
            else
                red "     >> U20-TEMP: file Structure Check: FAILED."
            fi
        else
            red "   >> U20-TEMP: DOWNLOAD: FAILED."
        fi
    else
        green "   >> ULTIMATE: Latest update has installed."
    fi
}

startscriptMSG() {
yellow "EXTREME HIVE OS - STARTING ===================================="
blue " > VERSION: $ULTIMATE_VERSION"

if [ "$SYSTEMBIN" -eq 1 ]; then
	blue " > SYSTEM-VERSION: $ULTIMATE_BIN_VERSION"
else
	red " > SYSTEM-VERSION: Not Installed"
fi

blue " > ONLINE VERSION: $ULTEXON_VERSION"

}


xrayStatVar="0"
xrayStats="[FAILED]"

vpnxraycheck() {
    yellow "VPN CHECK ==================================================="

    # Check if the Xray service is active
    if systemctl is-active --quiet xray; then
        xrayStatVar="1"
        xrayStats="[OK]"
    else
        xrayStatVar="0"
        xrayStats="[FAILED]"
    fi

    # Output the status of the Xray service
    if [ "$xrayStatVar" = "1" ]; then
        green " > XRAY: Running Fine with config. $xrayStats"
        export http_proxy=127.0.0.1:10809
        export https_proxy=127.0.0.1:10809
    else
        red " > XRAY: ERROR: Not running properly. $xrayStats"
        blue "   >> SYSTEM: Unsetting http_proxy and https_proxy."
        echo
        sleep 1
        unset http_proxy
        unset https_proxy
    fi
}


netConfigCheck() {
    echo
    yellow " > NETCONNECT:"

    # Check if the local configuration file exists
    if [ ! -f "$LOCALCONFIGFILE" ]; then
        red "   >> ERROR: Local configuration file does not exist."
        echo
        yellow "   >> Downloading default configuration file..."

        # Attempt to download the default configuration file
        if wget -O "$LOCALCONFIGFILE" "$DEFCONFIGS"; then
            green "   >> Default configuration file downloaded successfully."
        else
            red "   >> ERROR: Failed to download the default configuration file."
            LOCALCONFIGFILESTAT="0"
            return
        fi
    else
        blue "   >> Local configuration file already exists."
    fi

    # Check if the PORT variable is defined in the configuration file
    if ! grep -q "^PPOORRT=" "$LOCALCONFIGFILE"; then
        red "   >> ERROR: PORT is not defined in the configuration file."
        LOCALCONFIGFILESTAT="0"
    else
        PPORT=$(grep "^PPOORRT=" "$LOCALCONFIGFILE" | cut -d'=' -f2)

        # Validate the PORT number
        if ! [[ $PPORT =~ ^[0-9]+$ ]]; then
            red "   >> ERROR: PORT is not a valid number."
            LOCALCONFIGFILESTAT="0"
        elif [ "$PPORT" -ge 65536 ] || [ "$PPORT" -le 0 ]; then
            red "   >> ERROR: PORT is out of range (1-65535)."
            LOCALCONFIGFILESTAT="0"
        else
            green "   >> NETCONNECT: Configuration is valid. PORT=$PPORT"
            LOCALCONFIGFILESTAT="1"
        fi
    fi
}


systemAppCheck() {
    yellow "SYSTEM-APPS-CHECK ============================================="

    # Check if resolvconf is installed
    if ! command -v resolvconf &> /dev/null; then
        red " > RESOLVCONF: Not installed."
        resolvConfVersion="Not installed"
    else
        resolvconfversion=$(dpkg-query -W --showformat='${Version}\n' resolvconf)
        green " > RESOLVCONF-VERSION: $resolvconfversion"
        resolvConfVersion=$resolvconfversion
    fi

    # Load DNS settings
    loadDNS

    # Check if Xray is installed
    if ! command -v xray &> /dev/null; then
        red " > XRAY-VERSION: Not installed."
        xrayAppVersion="Not installed"
        
        green " > Installing XRAY Latest Version..."
        if bash -c "$(curl -s -m 15 -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version v1.8.13; then
            bash -c "$(curl -s -m 15 -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install-geodata
            systemctl enable xray
            systemctl start xray
            green " > XRAY installation completed."
        else
            red " > ERROR: Failed to install XRAY."
        fi
    else
        green " > Updating XRAY to the latest version..."
        if bash -c "$(curl -s -m 10 -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version v1.8.13; then
            XRAY_VERSION_CURRENT=$(xray --version 2>&1 | awk '/Xray/ {print $2}')
            green " > XRAY-VERSION: $XRAY_VERSION_CURRENT"
            xrayAppVersion=$XRAY_VERSION_CURRENT
        else
            red " > ERROR: Failed to update XRAY."
        fi
    fi
}


readSystemVPNStatus() {

    # Read the VPN status from the configuration file
    if [ ! -f "$SYSTEM_VPN_STAT" ]; then
        red " > VPN-STATUS: Configuration file not found, disabling VPN."
        VPNROOTSTAT="Disabled"
        return
    fi

    sysvpn_status=$(cat "$SYSTEM_VPN_STAT")

    # Validate and interpret the VPN status
    case "$sysvpn_status" in
        0)
            yellow " > VPN-STATUS: Disabled by User Config"
            VPNROOTSTAT="Disabled"
            ;;
        1)
            green " > VPN-STATUS: Enabled by User Config"
            VPNROOTSTAT="Enabled"
            ;;
        *)
            red " > VPN-STATUS: Unknown VPN status, disabling due to an error."
            VPNROOTSTAT="Disabled"
            ;;
    esac
}


systemProxyEnabler() {
    echo "1" > "$SYSTEM_VPN_STAT"
    
    # Write proxy settings to the network configuration file
    {
        echo "export http_proxy=http://127.0.0.1:10809"
        echo "export https_proxy=http://127.0.0.1:10809"
    } > "$NETWORK_HTTPFILE"
    
    # Update the local configuration file
    if ! sed -i 's/^\(STATUS=\).*/\11/' "$LOCALCONFIGFILE"; then
        red "[ERROR] Failed to update STATUS in $LOCALCONFIGFILE."
        return 1
    fi

    green "[OK] > SYSTEM NETWORK HTTP PROXY HAS BEEN ENABLED."
}

systemProxyDisabler() {
    echo "0" > "$SYSTEM_VPN_STAT"
    
    # Disable proxy by writing a comment to the network configuration file
    echo "#DISABLE PROXY" > "$NETWORK_HTTPFILE"
    
    # Update the local configuration file
    if ! sed -i 's/^\(STATUS=\).*/\10/' "$LOCALCONFIGFILE"; then
        red "[ERROR] Failed to update STATUS in $LOCALCONFIGFILE."
        return 1
    fi

    red "[OK] > SYSTEM NETWORK HTTP PROXY HAS BEEN DISABLED."
}


hellobinupdater() {
hello_filepath="/hive/bin/hello"
backup_hello_filepath="/hive/bin/backup.hello"
if grep -qF "#SOCKSULTIMATE" "$hello_filepath"; then
    blue " > [HELLO] Commands already added. Skipping ..."
else
    if [ -n "$hello_filepath" ]; then
		if [ ! -f "$backup_hello_filepath" ]; then
			cp $hello_filepath $backup_hello_filepath
			green " > [HELLO] Backup file has created successfully."
		else
			blue " > [HELLO] Backup file already exists."
		fi

		hellopattern=$(grep -n "Make hello request" "$hello_filepath" | cut -d ":" -f 1)
		blue " > [HELLO] Target Line Number: $hellopattern"

		((hellopattern++))
		sed -i "${hellopattern}a\\#SOCKSULTIMATE" "$hello_filepath"

		((hellopattern++))
		sed -i "${hellopattern}a\socks5_proxy=\"socks5://127.0.0.1:10808\"" "$hello_filepath"

		((hellopattern++))
		sed -i "${hellopattern}a\target_url=\"https://myip.wtf/json\"" "$hello_filepath"

		((hellopattern++))
		sed -i "${hellopattern}a\XRAY_netTestResult=\$(curl -s -m 15 --connect-timeout 10 --socks5-hostname \$socks5_proxy myip.wtf/yaml 2>/dev/null)" "$hello_filepath"

		((hellopattern++))
		sed -i "${hellopattern}a\XRAYCONF_ISP=\$(echo \"\$XRAY_netTestResult\" | grep -Po 'YourFuckingISP: \"\\\K[^\"]+')" "$hello_filepath"

		((hellopattern++))
		sed -i "${hellopattern}a\if [[ -z \$XRAYCONF_ISP ]]; then" "$hello_filepath"

		((hellopattern++))
		sed -i "${hellopattern}a\    insecure=\"\"" "$hello_filepath"

		((hellopattern++))
		sed -i "${hellopattern}a\else" "$hello_filepath"

		((hellopattern++))
		sed -i "${hellopattern}a\    if [[ \$XRAYCONF_ISP == \"Cloudflare\"* ]]; then" "$hello_filepath"

		((hellopattern++))
		sed -i "${hellopattern}a\        insecure=\"--socks5-hostname \$socks5_proxy --insecure\"" "$hello_filepath"

		((hellopattern++))
		sed -i "${hellopattern}a\    fi" "$hello_filepath"

		((hellopattern++))
		sed -i "${hellopattern}a\fi" "$hello_filepath"
        green " > [HELLO] File Has updated successfully."
    else
        red " > [HELLO] [Error] Pattern not found in Hello."
    fi
fi
}


#!/bin/bash

# Define the path to the SSH configuration file
sshconfig_filepath="/etc/ssh/sshd_config"

sshconfigupdater() {
# Ensure the script is run with root privileges
if [ "$(id -u)" -ne "0" ]; then
    echo "This script must be run as root or with sudo."
    exit 1
fi

# Replace the specified parameters with new values
# Note: `-i` option is used to edit the file in place

# Replace ListenAddress value
sed -i 's/^ListenAddress .*/ListenAddress 0.0.0.0/' "$sshconfig_filepath"

sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' "$sshconfig_filepath"
sed -i 's/^ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' "$sshconfig_filepath"
sed -i 's/^UsePAM .*/UsePAM yes/' "$sshconfig_filepath"
echo "SSH configuration has been updated successfully."
sleep 1

systemctl restart ssh
}

msgbinupdater() {
    msg_filepath="/hive/bin/message"
    backup_msg_filepath="/hive/bin/backup.message"

    # Check if the backup file exists and create it if not
    if [ ! -f "$backup_msg_filepath" ]; then
        cp "$msg_filepath" "$backup_msg_filepath"
        green " > [MESSAGE] Backup file has been created successfully."
    else
        blue " > [MESSAGE] Backup file already exists."
    fi

    # Check if the pattern already exists
    if grep -qF "#SOCKSULTIMATEMSG" "$msg_filepath"; then
        blue " > [MESSAGE] Commands already added. Skipping ..."
        return
    fi

    # Find the line number where to insert the new content
    msgbinpattern=$(grep -n "DISABLE_CERT_CHECK" "$msg_filepath" | cut -d ":" -f 1)
    if [ -z "$msgbinpattern" ]; then
        red " > [MESSAGE] [Error] Pattern not found in MESSAGE."
        return
    fi

    blue " > [MESSAGE] Target Line Number: $msgbinpattern"

    # Append new content to the file
    {
        sed -i "${msgbinpattern}a\\" "$msg_filepath"
        ((msgbinpattern++))
        sed -i "${msgbinpattern}a\\#SOCKSULTIMATEMSG" "$msg_filepath"
        ((msgbinpattern++))
        sed -i "${msgbinpattern}a\\socks5_proxy=\"socks5://127.0.0.1:10808\"" "$msg_filepath"
        ((msgbinpattern++))
        sed -i "${msgbinpattern}a\\target_url=\"https://myip.wtf/json\"" "$msg_filepath"
        ((msgbinpattern++))
        sed -i "${msgbinpattern}a\\XRAY_netTestResult=\$(curl -s -m 15 --connect-timeout 10 --socks5-hostname \$socks5_proxy myip.wtf/yaml 2>/dev/null)" "$msg_filepath"
        ((msgbinpattern++))
        sed -i "${msgbinpattern}a\\XRAYCONF_ISP=\$(echo \"\$XRAY_netTestResult\" | grep -Po 'YourFuckingISP: \"\\\K[^\"]+')" "$msg_filepath"
        ((msgbinpattern++))
        sed -i "${msgbinpattern}a\\if [[ -z \$XRAYCONF_ISP ]]; then" "$msg_filepath"
        ((msgbinpattern++))
        sed -i "${msgbinpattern}a\\    insecure=\"\"" "$msg_filepath"
        ((msgbinpattern++))
        sed -i "${msgbinpattern}a\\else" "$msg_filepath"
        ((msgbinpattern++))
        sed -i "${msgbinpattern}a\\    if [[ \$XRAYCONF_ISP == \"Cloudflare\"* ]]; then" "$msg_filepath"
        ((msgbinpattern++))
        sed -i "${msgbinpattern}a\\        insecure=\"--socks5-hostname \$socks5_proxy --insecure\"" "$msg_filepath"
        ((msgbinpattern++))
        sed -i "${msgbinpattern}a\\    fi" "$msg_filepath"
        ((msgbinpattern++))
        sed -i "${msgbinpattern}a\\fi" "$msg_filepath"
        ((msgbinpattern++))
        sed -i "${msgbinpattern}a\\" "$msg_filepath"
    } 

    green " > [MESSAGE] File has been updated successfully."
}


nettestbinupdater() {
    nettest_filepath="/hive/bin/net-test"
    backup_nettest_filepath="/hive/bin/backup.net-test"
    pingpattern_nettest="ping -i 0 -q -c 1 -w 4"
    pingpattern_replacement="timeout 5 ping -i 0 -q -c 1"

    # Check if the backup file exists and create it if not
    if [ ! -f "$backup_nettest_filepath" ]; then
        cp "$nettest_filepath" "$backup_nettest_filepath"
        green " > [NETTEST] Backup file has been created successfully."
    else
        blue " > [NETTEST] Backup file already exists."
    fi

    # Fix the ping pattern if it exists
    if grep -qF "$pingpattern_nettest" "$nettest_filepath"; then
        sed -i "s@$pingpattern_nettest@$pingpattern_replacement@g" "$nettest_filepath"
        green " > [NETTEST] Ping bug has been fixed successfully."
    else
        blue " > [NETTEST] Ping bug has already been fixed."
    fi

    # Check if the commands have already been added
    if grep -qF "#SOCKSULTIMATENETTEST" "$nettest_filepath"; then
        blue " > [NETTEST] Commands already added. Skipping ..."
        return
    fi

    # Find the line number where to insert the new content
    nettestbinpattern=$(grep -n "DISABLE_CERT_CHECK" "$nettest_filepath" | cut -d ":" -f 1)
    if [ -z "$nettestbinpattern" ]; then
        red " > [NETTEST] [Error] Pattern not found in NETTEST."
        return
    fi

    blue " > [NETTEST] Target Line Number: $nettestbinpattern"

    # Append new content to the file
    {
        sed -i "${nettestbinpattern}a\\" "$nettest_filepath"
        ((nettestbinpattern++))
        sed -i "${nettestbinpattern}a\\#SOCKSULTIMATENETTEST" "$nettest_filepath"
        ((nettestbinpattern++))
        sed -i "${nettestbinpattern}a\\socks5_proxy=\"socks5://127.0.0.1:10808\"" "$nettest_filepath"
        ((nettestbinpattern++))
        sed -i "${nettestbinpattern}a\\target_url=\"https://myip.wtf/json\"" "$nettest_filepath"
        ((nettestbinpattern++))
        sed -i "${nettestbinpattern}a\\XRAY_netTestResult=\$(curl -s -m 15 --connect-timeout 10 --socks5-hostname \$socks5_proxy myip.wtf/yaml 2>/dev/null)" "$nettest_filepath"
        ((nettestbinpattern++))
        sed -i "${nettestbinpattern}a\\XRAYCONF_ISP=\$(echo \"\$XRAY_netTestResult\" | grep -Po 'YourFuckingISP: \"\\\K[^\"]+')" "$nettest_filepath"
        ((nettestbinpattern++))
        sed -i "${nettestbinpattern}a\\if [[ -z \$XRAYCONF_ISP ]]; then" "$nettest_filepath"
        ((nettestbinpattern++))
        sed -i "${nettestbinpattern}a\\    insecure=\"\"" "$nettest_filepath"
        ((nettestbinpattern++))
        sed -i "${nettestbinpattern}a\\else" "$nettest_filepath"
        ((nettestbinpattern++))
        sed -i "${nettestbinpattern}a\\    if [[ \$XRAYCONF_ISP == \"Cloudflare\"* ]]; then" "$nettest_filepath"
        ((nettestbinpattern++))
        sed -i "${nettestbinpattern}a\\        insecure=\"--socks5-hostname \$socks5_proxy --insecure\"" "$nettest_filepath"
        ((nettestbinpattern++))
        sed -i "${nettestbinpattern}a\\    fi" "$nettest_filepath"
        ((nettestbinpattern++))
        sed -i "${nettestbinpattern}a\\fi" "$nettest_filepath"
        ((nettestbinpattern++))
        sed -i "${nettestbinpattern}a\\" "$nettest_filepath"
    } 

    green " > [NETTEST] File has been updated successfully."
}

ultexUpdater() {
    ULTEXFILEURL="$DEFURL/$configFileName"
    ULTEXFILE="/hive/bin/ultex"

    # Print informational message
    infoprint

    # Check if the ultex file already exists
    if [ ! -f "$ULTEXFILE" ]; then
        yellow " > [NETTEST] Downloading ultex file"
        # Attempt to download the file
        if wget -O "$ULTEXFILE" "$ULTEXFILEURL"; then
            green " > [NETTEST] ultex file downloaded successfully."
            chmod +x "$ULTEXFILE"
        else
            red "   >> ERROR: Failed to download ultex file."
        fi
    else
        blue " > [NETTEST] ultex file already exists."
        chmod +x "$ULTEXFILE"
    fi
}

motdbinupdater() {
motd_filepath="/hive/bin/motd"
backup_motd_filepath="/hive/bin/backup.motd"
if grep -qF "#SOCKSULTIMATE" "$motd_filepath"; then
    blue " > [METHOD] Commands already added. Skipping ..."
else
    if [ -n "$motd_filepath" ]; then
		if [ ! -f "$backup_motd_filepath" ]; then
			cp $motd_filepath $backup_motd_filepath
			green " > [METHOD] Backup file has created successfully."
		else
			blue " > [METHOD] Backup file already exists."
		fi

		motdpattern=$(grep -n "motd_watch()" "$motd_filepath" | cut -d ":" -f 1)
		blue " > [METHOD] Target Line Number: $motdpattern"

		((motdpattern++))
		sed -i "${motdpattern}a\\        #SOCKSULTIMATE" "$motd_filepath"

		((motdpattern++))
		sed -i "${motdpattern}a\        exit 0" "$motd_filepath"

        green " > [METHOD] File Has updated successfully."
    else
        red " > [METHOD] [Error] Pattern not found in Hello."
    fi
fi
}

minerfileUpdater() {
miner_filepath="/hive/bin/miner"
backup_miner_filepath="/hive/bin/backup.miner"

if grep -qF "#SOCKSULTIMATEMINER" "$miner_filepath"; then
    blue " > [MINER] Commands already added. Skipping ..."
else
    if [ -n "$miner_filepath" ]; then
		if [ ! -f "$backup_miner_filepath" ]; then
			cp $miner_filepath $backup_miner_filepath
			green " > [MINER] Backup file has created successfully."
		else
			blue " > [MINER] Backup file already exists."
		fi

		minerbinpattern=$(grep -n "/usr/bin/env bash" "$miner_filepath" | cut -d ":" -f 1)
		blue " > [MINER] Target Line Number: $minerbinpattern"

		sed -i "${minerbinpattern}a\\
" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\\#SOCKSULTIMATEMINER" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\SYSUUID=\$(<\"/hive-config/SERIAL\")" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\GTHUBFILEURL=\"https://raw.githubusercontent.com/UltimateABC/Amestris-Kernel-9192-S4mini/master/devicelist.md\"" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\sleep 1" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\GTHUBCONTENTS=\$(curl -m 20 -s \"\$GTHUBFILEURL\")" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\if [ -z \"\$GTHUBCONTENTS\" ]" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\then" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\	exit 1" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\else" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\	if echo \"\$GTHUBCONTENTS\" | grep -q \"^\$SYSUUID\"; then" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\		systemctl start xray" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\	else" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\		if [ -e \"/tmp/um20\" ]; then" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\			echo \"Skip Sending Error\"" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\		else" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\			touch \"/tmp/um20\"" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\			/hive/bin/message error \"Not Registered RIG, VPN Stopped.\"" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\			/hive/bin/message warning \"ID: \$SYSUUID\"" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\			\#systemctl stop xray" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\			sleep 2" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\			\#exit 0" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\		fi" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\	fi" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\fi" "$miner_filepath"

		((minerbinpattern++))
		sed -i "${minerbinpattern}a\\
" "$miner_filepath"

		minerconfigpattern=$(grep -n "config()" "$miner_filepath" | cut -d ":" -f 1)
		blue " > [MINER] config line: $minerconfigpattern"
		
		sed -i "${minerconfigpattern}a\\
" "$miner_filepath"

		((minerconfigpattern++))
		sed -i "${minerconfigpattern}a\\        #SOCKSULTIMATEMINER" "$miner_filepath"
		((minerconfigpattern++))
		sed -i "${minerconfigpattern}a\        exit 0" "$miner_filepath"
		((minerconfigpattern++))
		sed -i "${minerconfigpattern}a\\
" "$miner_filepath"

        green " > [MINER] File Has updated successfully."
    else
        red " > [MINER] [Error] Pattern not found in MINER."
    fi
fi

}

updaterLocalRC() {

    rclocal_filepath="/etc/rc.local"

    # Check if the commands have already been added
    if grep -qF "#SOCKSULTIMATE-BOOTEX" "$rclocal_filepath"; then
        blue " > [LOCAL-RC] Commands already added. Skipping ..."
    else
        # Clear the file and write the new script
        {
            echo "#!/bin/bash"
            echo "##!/bin/sh -e"
            echo ""
            echo "#SOCKSULTIMATE-BOOTEX"
            echo "ultexbootfile=/root/ultex.boot"
            echo ""
            echo "if [ -e \"\$ultexbootfile\" ]; then"
            echo "    echo \"File \$ultexbootfile exists. Deleting...\""
            echo "    rm \"\$ultexbootfile\""
            echo "    echo \"File \$ultexbootfile deleted.\""
            echo "else"
            echo "    echo \"File \$ultexbootfile does not exist.\""
            echo "fi"
            echo ""
            echo "/hive/bin/ultex"
            echo ""
            echo "exit 0"
        } > "$rclocal_filepath"

        # Make sure the script is executable
        chmod +x "$rclocal_filepath"

        green " > [LOCAL-RC] Has Updated and Implemented."
        echo
    fi
}

passwordEnter() {
    # Prompt user to enter the password
    echo -n "Enter the password: "
    read -s password
    echo

    # Define the correct password
    correct_password="power12"

    # Compare entered password with the correct one
    if [ "$password" == "$correct_password" ]; then
        echo "Password is correct."
    else
        echo "Incorrect password. Exiting..."
        exit 1
    fi
}


makingconfigjsons() {

    netConfigCheck

    # Ensure the XRAY config directory exists
    if [ ! -d "$XRAY_CONFIG_DIR" ]; then
        green "Creating directory $XRAY_CONFIG_DIR..."
        mkdir -p "$XRAY_CONFIG_DIR"
        green "Directory $XRAY_CONFIG_DIR created."
    fi

    infoprint

    # Clean up old config files
    blue " > Cleaning Old config files . . ."
    for file in "$SOURCE_GTI" "$SOURCE_WRC"; do
        if [ -e "$file" ]; then
            rm "$file"
            blue "   >> Deleting $file."
        fi
    done
    infoprint
    sleep 1

    yellow " > Download and Updating Config files."

    proxyWorkingCheck

    # Download and check the WRC file
    if curl -m 20 -sSf "$WRCURL_SERVERA1" -o "$SOURCE_WRC"; then
        green "   >> SOURCE-WRC:$SERVERA1: DOWNLOAD: OK."
        if grep -q '"routing":' "$SOURCE_WRC"; then
            green "     >>> SOURCE-WRC:$SERVERA1: JSON file Structure Check: OK."
            infoprint
            cp "$SOURCE_WRC" "$SA1_DESTINATION_IRANCELL_WRC"
            blue "   >> IRANCELL_WRC file has created successfully."
            cp "$SOURCE_WRC" "$SA1_DESTINATION_HAMRAH_WRC"
            blue "   >> HAMRAH_WRC file has created successfully."
        else
            red "     >>> SOURCE-WRC:$SERVERA1: JSON file Structure Check: FAILED."
        fi
    else
        red "   >> SOURCE-WRC:$SERVERA1: DOWNLOAD: FAILED."
    fi

    infoprint

    # Download and check the GTI file
    if curl -m 20 -sSf "$GTIURL_SERVERA1" -o "$SOURCE_GTI"; then
        green "   >> SOURCE-GTI:$SERVERA1: DOWNLOAD: OK."
        if grep -q '"routing":' "$SOURCE_GTI"; then
            green "     >>> SOURCE-GTI:$SERVERA1: JSON file Structure Check: OK."
            infoprint
            cp "$SOURCE_GTI" "$SA1_DESTINATION_IRANCELL_GTI"
            blue "   >> IRANCELL_GTI file has created successfully."
            cp "$SOURCE_GTI" "$SA1_DESTINATION_HAMRAH_GTI"
            blue "   >> HAMRAH_GTI file has created successfully."
        else
            red "     >> SOURCE-GTI:$SERVERA1: JSON file Structure Check: FAILED."
        fi
    else
        red "   >> SOURCE-GTI:$SERVERA1: DOWNLOAD: FAILED."
    fi

    # Function to replace variables in config files
    replace_variables() {
        source "$LOCALCONFIGFILE"
        if [ "$InstallMode" -eq 1 ]; then
            blue "   >> Updating Values for $1 file [OK]"
        fi
        sed -i "s/SERVERNAME/$SERVERNAME/g" "$1"
        sed -i "s/SSCONFIGPASSWORD/$SSCONFIGPASSWORD/g" "$1"
        sed -i "s/IDNUMBERXD/$IDNUMBERXD/g" "$1"
        sed -i "s/IDNUMBERID/$IDNUMBERID/g" "$1"
        sed -i "s/SERVICEGRPCNAME/$SERVICEGRPCNAME/g" "$1"
        sed -i "s/WSPATH/$WSPATH/g" "$1"
        sed -i "s/PPOORRT/$PPOORRT/g" "$1"
    }

    # Update configuration files if the local config file is valid
    if [ "$LOCALCONFIGFILESTAT" = "1" ]; then
        infoprint
        source "$LOCALCONFIGFILE"
        green " > NET-CONNECT: CONFIG FILE: [OK]"
        if [ "$InstallMode" -eq 1 ]; then
            blue "   >>   - ServerName= $SERVERNAME"
            blue "   >>   - Password= $SSCONFIGPASSWORD"
            blue "   >>   - ID Number 1= $IDNUMBERXD"
            blue "   >>   - ID Number 2= $IDNUMBERID"
            blue "   >>   - GRPC Name= $SERVICEGRPCNAME"
            blue "   >>   - WS Path= $WSPATH"
            blue "   >>   - PORT= $PPOORRT"
            infoprint
        fi
        replace_variables "$SA1_DESTINATION_IRANCELL_WRC"
        replace_variables "$SA1_DESTINATION_IRANCELL_GTI"
        replace_variables "$SA1_DESTINATION_HAMRAH_GTI"
        replace_variables "$SA1_DESTINATION_HAMRAH_WRC"

        # Updating the IP for Network
        if [ "$InstallMode" -eq 1 ] || [ "$DebugMode" -eq 1 ]; then
            yellow "   >> Updating NETWORK IPs for Configs."
            blue "     >>> Hamrah Aval IP: $OPERATORAVAL"
            blue "     >>> Irancell IP:    $OPERATORCELL"
        fi
        sed -i "s/OPERATOR/$OPERATORAVAL/g" "$SA1_DESTINATION_HAMRAH_WRC"
        sed -i "s/OPERATOR/$OPERATORAVAL/g" "$SA1_DESTINATION_HAMRAH_GTI"
        sed -i "s/OPERATOR/$OPERATORCELL/g" "$SA1_DESTINATION_IRANCELL_WRC"
        sed -i "s/OPERATOR/$OPERATORCELL/g" "$SA1_DESTINATION_IRANCELL_GTI"
    else
        red " > NET-CONNECT: CONFIG FILE: ERROR [FAILED]"
    fi

    infoprint
}


# Function to update the VPN status based on local and system settings
vpnstatusUpdater() {
    if [ "$LOCAL_VPNSTATUS" != "$sysvpn_status" ]; then
        if [ "$LOCAL_VPNSTATUS" = "1" ]; then
            echo "1" > "$SYSTEM_VPN_STAT"
            successMSG "VPN Service is turned ON"
            green "VPN Service is turned ON"
            systemProxyEnabler
        elif [ "$LOCAL_VPNSTATUS" = "0" ]; then
            echo "0" > "$SYSTEM_VPN_STAT"
            successMSG "VPN Service is turned OFF"
            green "VPN Service is turned OFF"
            systemProxyDisabler
        fi
        successMSG "VPN status has changed. Rebooting..."
        sleep 1
        red "SYSTEM - REBOOT"
        /hive/sbin/sreboot
    fi
}

# Function to check the status of the XRay service
xRayStatCheck() {
    xrayStatusCMD=$(systemctl status xray)

    if [[ $xrayStatusCMD =~ "Active: active (running)" ]]; then
        xrayStatVar="1"
        xrayStats="[OK]"
    else
        xrayStatVar="0"
        xrayStats="[FAILED]"
    fi
}

# Function to apply the XRay service status and configure proxies
xRayStatApply() {
    if [ "$xrayStatVar" = "1" ]; then
        green " > VPN PROXY: Running Fine with config."
        export http_proxy="127.0.0.1:10809"
        export https_proxy="127.0.0.1:10809"
    else
        red " > VPN PROXY: ERROR: Not running properly."
        blue "   >> SYSTEM: Unsetting http_proxy."
        unset http_proxy
        unset https_proxy
    fi
}

# Function to update the cron job file with specific commands
fileCronUpdater() {
    crontabfilepath="/hive/etc/crontab.root"

    if grep -qF "#CRONTABULTEX" "$crontabfilepath"; then
        blue " > [CRONS] Commands already added. Skipping..."
    else
        {
            echo ""
            echo "#CRONTABULTEX"
            echo "*/10 * * * * /hive/bin/hello"
            echo ""
        } >>"$crontabfilepath"
        green " > [CRONS] File has been updated successfully."
    fi
}

# Function to select and apply the best XRay config based on ping results
xRaySConfigSelector() {
    [ -f "$TESTPING_RESULT_FILE" ] && > "$TESTPING_RESULT_FILE" || touch "$TESTPING_RESULT_FILE"

    for config_file in $(find "$XRAY_CONFIG_DIR" -name '*.json'); do
        systemctl stop xray
        cp "$config_file" "$XRAYDEFCONFIG"
        chmod 777 "$XRAYDEFCONFIG"
        systemctl start xray
        sleep 5
        xRayStatCheck
        sleep 1

        if [ "$xrayStatVar" = "1" ]; then
            if [ "$InstallMode" -eq 1 ] || [ "$DebugMode" -eq 1 ]; then
                validConf="$config_file"
            else
                validConf="Config"
            fi
            green "$xrayStats [$validConf] "

            XRAY_netTestResult=$(curl -s -m 15 --socks5-hostname 127.0.0.1:$socks_port myip.wtf/yaml 2>/dev/null)
            XRAYCONF_ISP=$(echo "$XRAY_netTestResult" | grep -Po 'YourFuckingISP: "\K[^"]+')
            sleep 1

            if [[ -z $XRAYCONF_ISP ]]; then
                red "   >> [ERROR]: Unable to retrieve ISP information."
            elif [[ $XRAYCONF_ISP == "Cloudflare"* ]]; then
                total_ping=0
				
                if [ "$InstallMode" -eq 1 ] || [ "$DebugMode" -eq 1 ]; then
					blue "   >> [TESTING]: $config_file"
				fi

                for ((i = 1; i <= 3; i++)); do
                    TEST_PING=$(curl --silent --connect-timeout 10 --max-time 10 --socks5-hostname localhost:$socks_port -o /dev/null -s -w 'Total: %{time_total}\n' google.com | cut -d' ' -f2)
                    sleep 1
                    total_ping=$(echo "$total_ping + $TEST_PING" | bc)
                done

                avg_ping=$(echo "scale=2; $total_ping / 3" | bc)
                blue "      - AVERAGE PING TIME: $avg_ping seconds"
                echo "$config_file= $avg_ping" >>"$TESTPING_RESULT_FILE"
            fi
        else
            red "$xrayStats [$config_file] "
        fi
        echo
    done

    lowest_value=9999
    lowest_file=""

    while IFS='=' read -r file value; do
        num=$(echo "$value" | tr -d ' ')
        if (( $(echo "$num < $lowest_value" | bc -l) )); then
            lowest_value=$num
            lowest_file=$file
        fi
    done <"$TESTPING_RESULT_FILE"

    yellow " > XRAY: Set Default Config"

    if [ "$InstallMode" -eq 1 ] || [ "$DebugMode" -eq 1 ]; then
        green "       - FileName  : [ $lowest_file ] "
    fi
    green "       - Ping Time : [ $lowest_value ] seconds"

    systemctl stop xray
    cp "$lowest_file" "$XRAYDEFCONFIG"
    echo "$lowest_file" >"$SYSTEM_XRAYVPN_LOG"

    chmod 777 "$XRAYDEFCONFIG"
    sleep 1
    systemctl start xray
}

sshservicefixer() {

    sshconfig_file="/etc/ssh/sshd_config"

    # Check if the sshconfig_file exists
    if [ ! -f "$sshconfig_file" ]; then
        red "ERROR: SSH configuration file not found: $sshconfig_file"
        return 1
    fi

    # Remove immutable attribute to modify the file
    chattr -ai "$sshconfig_file"

    # Check and update the PasswordAuthentication setting
    if ! grep -q "^PasswordAuthentication yes" "$sshconfig_file"; then
        infoprint "PasswordAuthentication value is not set to 'yes'. Updating..."
        if grep -q "^PasswordAuthentication" "$sshconfig_file"; then
            # Update the existing entry
            sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$sshconfig_file"
        else
            # Add the setting if it doesn't exist
            echo "PasswordAuthentication yes" >> "$sshconfig_file"
        fi
        green "PasswordAuthentication has been set to 'yes'."
    else
        infoprint "PasswordAuthentication value is already set to 'yes'. No changes needed."
    fi

    # Check and update the ListenAddress setting
    if ! grep -q "^ListenAddress 0.0.0.0" "$sshconfig_file"; then
        infoprint "ListenAddress is not set to '0.0.0.0'. Updating..."
        if grep -q "^ListenAddress" "$sshconfig_file"; then
            # Update the existing entry
            sed -i 's/^ListenAddress.*/ListenAddress 0.0.0.0/' "$sshconfig_file"
        else
            # Add the setting if it doesn't exist
            echo "ListenAddress 0.0.0.0" >> "$sshconfig_file"
        fi
        green "ListenAddress has been set to '0.0.0.0'."
    else
        infoprint "ListenAddress is already set to '0.0.0.0'. No changes needed."
    fi

    # Reapply the immutable attribute to the file
    chattr +ai "$sshconfig_file"

    # Restart the SSH service to apply changes
    if systemctl restart sshd; then
        green "SSH service restarted successfully."
    else
        red "ERROR: Failed to restart SSH service."
    fi

}


minerfileUpdater2() {

miner_filepath="/hive/bin/miner"

if grep -qF "#SOCKSV2ULTIMATEMINER" "$miner_filepath"; then
    blue " > [MINER] V2 has Installed ..."
else
    blue " > [MINER] Updating To version 2"
	sed -i 's/#SOCKSULTIMATEMINER/#SOCKSV2ULTIMATEMINER/g' $miner_filepath
	sed -i '/^\s*#systemctl stop xray\s*$/!b;n;c\                        sleep 60' $miner_filepath
	sed -i '/^\s*sleep 60\s*$/a\                        /hive/sbin/sreboot' $miner_filepath
fi
}

mainScriptStart() {
loadDNS
loadColors
debugInfo "Ultimate v $ULTIMATE_VERSION"
networkcheck
defaultConfigVals
sshconfigupdater
ultbinUpdater
startscriptMSG
vpnxraycheck
netConfigCheck
systemAppCheck
readSystemVPNStatus
hellobinupdater
msgbinupdater
nettestbinupdater
ultexUpdater
minerfileUpdater
minerfileUpdater2
#installClienTuneLocal
#installClienTunelService
disableClientTunelService
#systemctl start clieNTUL
#rootBashRCupdater
#homeBashRCupdater
motdbinupdater
fileCronUpdater
updaterLocalRC
#proxyWorkingCheck
makingconfigjsons
readSystemVPNStatus
xRayStatCheck
xRayStatApply
xRaySConfigSelector
vpnstatusUpdater
sshservicefixer
successMSG "Ultimate OS v $ULTIMATE_VERSION has Started"
}

# Main script logic
if [ $# -eq 0 ]; then
    echo " [START] Ultimate OS v$ULTIMATE_VERSION"

    # Ensure InstallMode is set to 0 if not already defined
    if [[ -z "$InstallMode" || ! "$InstallMode" =~ ^[0-9]+$ ]]; then
        InstallMode=0
    fi
	
	if [[ -z "$DebugMode" || ! "$DebugMode" =~ ^[0-9]+$ ]]; then
        DebugMode=0
    fi
    
    # Call the main script start function
    mainScriptStart

elif [ "$1" == "debug" ]; then 
	DebugMode=1
	mainScriptStart

elif [ "$1" == "install" ]; then 
    echo "Installation Mode has been selected"
    
    # Set InstallMode to 1 for installation mode
    InstallMode=1
    
    # Set the SSH password
    /hive/sbin/hive-passwd set ssd
    
    # Prompt user for a password
    passwordEnter
    
    # Remove the ultex file before starting the main script
    rm -f /hive/bin/ultex
    
    # Call the main script start function
    mainScriptStart
    
    # Print finish message and reboot the system
    infoprint "[FINISH] Ultimate OS v$ULTIMATE_VERSION - REBOOT"
    sleep 20
    /hive/sbin/sreboot
else
    exit 0
fi

# If UUPDATESTAT is set to 1, reboot the system
if [ "$UUPDATESTAT" -eq 1 ]; then
    /hive/sbin/sreboot
    successMSG "Updated to Ultimate OS v $ULTEXON_VERSION ...rebooting"
fi
