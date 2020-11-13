#!/bin/bash

function env_vars() {
    ISO=rhcos_live.iso
    SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
    NMCON_TEMPLATE=${SCRIPTPATH}/nmcon-template
    AI_STATIC_ADDRESSES_PATH="/tmp/AI_STATIC_INV"
    AI_NM_CONN_TEMP_PATH="/tmp/AI_NMCONN_BASE"
    create_template_files
}

function create_template_files() {
    cat > ${AI_NM_CONN_TEMP_PATH} <<EOF
[connection]
id=\$FOUND_INTERFACE
interface-name=\$FOUND_INTERFACE
type=ethernet
multi-connect=3
autoconnect=true
autoconnect-priority=1

[ethernet]
mac-address-blacklist=

[ipv4]
method=auto
addr-gen-mode=eui64

[ipv6]
method=manual
addresses=\$FOUND_IP/\$FOUND_PREFIX
gateway=\$FOUND_GW
dns=\$FOUND_DNS
dns-search=\$FOUND_SE_DOMAIN

[802-3-ethernet]
mac-address=\$FOUND_MAC
EOF
}

function find_my_mac() {
    MAC_TO_CHECK=${1}

    for entry in $(cat ${AI_STATIC_ADDRESSES_PATH})
    do
        MAC=$(echo ${entry} | cut -f2 -d\;)
        if [[ ! -z ${MAC} ]] && [[ -z ${FOUND_MAC} ]]; then
            if [[ "${MAC}" == "${MAC_TO_CHECK}" ]]; then
		export FOUND_INTERFACE=${INTERFACE}
                export FOUND_MAC=${MAC}
                export FOUND_IP=$(echo ${entry} | cut -f1 -d\;) 
                export FOUND_PREFIX=$(echo ${entry} | cut -f3 -d\;) 
                export FOUND_GW=$(echo ${entry} | cut -f4 -d\;) 
                export FOUND_SE_DOMAIN=$(echo ${entry} | cut -f5 -d\;) 
                export FOUND_DNS=$(echo ${entry} | cut -f6 -d\;) 
                break
            fi
        fi
    done

    if [[ -z ${FOUND_MAC} ]]; then
        echo "Host MAC ${MAC_TO_CHECK} not found in the list" | systemd-cat -t configure-static-ip -p err
    fi
}

function correlate_int_mac() {
    # Correlate the Mac with the interface
    for INTERFACE in $(find /sys/class/net -mindepth 1 -maxdepth 1 ! -name lo -printf "%P\n")
    do
        INT_MAC=$(cat /sys/class/net/${INTERFACE}/address)
        if [[ ! -z ${INT_MAC} ]]; then
            echo "MAC to check: ${INT_MAC}" | systemd-cat -t configure-static-ip -p debug
            find_my_mac ${INT_MAC}
            if [[ "${FOUND_MAC}" == "${INT_MAC}" ]];then
                echo "MAC Found in the list, this is the Net data: " | systemd-cat -t configure-static-ip -p debug
                echo "MAC: ${FOUND_MAC}" | systemd-cat -t configure-static-ip -p debug
                echo "IP: ${FOUND_IP}" | systemd-cat -t configure-static-ip -p debug
                echo "MASK: ${FOUND_PREFIX}" | systemd-cat -t configure-static-ip -p debug
                echo "GW: ${FOUND_GW}" | systemd-cat -t configure-static-ip -p debug
                echo "SEARCH DOMAIN: ${FOUND_SE_DOMAIN}" | systemd-cat -t configure-static-ip -p debug
                echo "DNS: ${FOUND_DNS}" | systemd-cat -t configure-static-ip -p debug
                break
            fi
        fi
    done

    if [[ -z ${FOUND_INTERFACE} ]];then
        echo "Interface with MAC ${INT_MAC} address ${INT_MAC} not found" | systemd-cat -t configure-static-ip -p err
        exit 1
    fi

    export NM_KEY_FILE="/etc/NetworkManager/system-connections/${FOUND_INTERFACE}.nmconnection"
    envsubst < ${AI_NM_CONN_TEMP_PATH} > ${NM_KEY_FILE}
    chmod 600 ${NM_KEY_FILE}
}

env_vars
#generate_mock_file
correlate_int_mac
