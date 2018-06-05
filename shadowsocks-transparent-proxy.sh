#!/bin/bash

echoerr() { echo "$@" 1>&2; }
do_iptables() {
    if [ "$DEBUG" == "1" ]; then
        echo "iptables $@"
    else
        iptables $@
    fi
}
do_ipset() {
    if [ "$DEBUG" == "1" ]; then
        echo "ipset $@"
    else
        ipset $@
    fi
}
do_ss_redir() {
    if [ "$DEBUG" == "1" ]; then
        echo "ss-redir $@"
    else
        ss-redir $@
    fi
}
clear_rules() {
    echo "Clearing rules"
    do_iptables -t nat -D OUTPUT -p tcp -j SHADOWSOCKS
    do_iptables -t nat -F SHADOWSOCKS
    do_iptables -t nat -X SHADOWSOCKS
    do_ipset destroy chinaip
}
find_script_path() {
    SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
}

find_script_path

# MUST be run as root
if [ `id -u` != "0" ]; then
    echoerr "This script MUST BE run as ROOT"
    exit 1
fi

CONFIG_PATH="$1"

if [ "$CONFIG_PATH" == "" ]; then
    echoerr "Usage: shadowsocks-auto-redir <path to config.json>"
    exit 1
elif [ "$CONFIG_PATH" == "clear" ]; then
    clear_rules
    exit 0
elif [ ! -f "$CONFIG_PATH" ]; then
    echoerr "$CONFIG_PATH does not exist"
    exit 1
fi

do_iptables -t nat -N SHADOWSOCKS

# Bypass ips
SERVER=`jq -r ".server" $CONFIG_PATH`

if [[ $SERVER =~ "127."* ]]; then
    echo "Skipping local address $SERVER"
else
    do_iptables -t nat -A SHADOWSOCKS -d $SERVER -j RETURN
fi

BYPASS_IPS=`jq -r ".ss_redir_options.bypass_ips" $CONFIG_PATH`

if [[ "$BYPASS_IPS" != "null" ]]; then
    # Should only iterate when the item is not null
    BYPASS_IPS=`jq -r ".ss_redir_options.bypass_ips[]" $CONFIG_PATH`
    for ip in $BYPASS_IPS; do
        do_iptables -t nat -A SHADOWSOCKS -d $ip -j RETURN
    done
fi

# Allow connection to preserved networks
do_iptables -t nat -A SHADOWSOCKS -d 0.0.0.0/8 -j RETURN
do_iptables -t nat -A SHADOWSOCKS -d 10.0.0.0/8 -j RETURN
do_iptables -t nat -A SHADOWSOCKS -d 127.0.0.0/8 -j RETURN
do_iptables -t nat -A SHADOWSOCKS -d 169.254.0.0/16 -j RETURN
do_iptables -t nat -A SHADOWSOCKS -d 172.16.0.0/12 -j RETURN
do_iptables -t nat -A SHADOWSOCKS -d 192.168.0.0/16 -j RETURN
do_iptables -t nat -A SHADOWSOCKS -d 224.0.0.0/4 -j RETURN
do_iptables -t nat -A SHADOWSOCKS -d 240.0.0.0/4 -j RETURN

# Load bypass route set
do_ipset -N chinaip hash:net

BYPASS_PRESET=`jq -r ".ss_redir_options.bypass_preset" $CONFIG_PATH`

if [[ "$BYPASS_PRESET" == "chnroute" ]]; then
    for ip in `cat $SCRIPT_PATH/routes/chnroute.txt`; do
        do_ipset add chinaip $ip
    done
fi

do_iptables -t nat -A SHADOWSOCKS -p tcp -m set --match-set chinaip dst -j RETURN

# Redirect to ss-redir port
LOCAL_PORT=`jq -r ".local_port" $CONFIG_PATH`

do_iptables -t nat -A SHADOWSOCKS -p tcp -j REDIRECT --to-port $LOCAL_PORT

# Apply rules
do_iptables -t nat -A OUTPUT -p tcp -j SHADOWSOCKS

# Build ss-redir params
SS_PARAMS="-c $CONFIG_PATH"

if [[ `jq -r ".ss_redir_options.ota" $CONFIG_PATH` == "true" ]]; then
    SS_PARAMS="-A $SS_PARAMS"
fi

if [[ $UDP_ENABLED == "true" ]]; then
    SS_PARAMS="-u $SS_PARAMS"
fi
do_ss_redir $SS_PARAMS

# ss-redir has exited.
clear_rules
