#!/bin/bash

function generate_mock_file() {
    export SEED_FAKE_IP=192.168.122
    export SEED_FAKE_MAC=de:ad:be:ef:00
    export NETMASK=255.255.255.0
    export PREFIX=24
    export GATEWAY=192.168.122.1
    export SEARCH_DOMAIN=e2e.bos.redhat.com
    export DNS1=192.168.122.1
    export DNS2=8.8.8.8
    export VLAN=false
    export BOND=false
    echo > "${AI_STATIC_ADDRESSES_PATH}"

    for ID in {10..99} 
    do
        echo "${SEED_FAKE_IP}.${ID};${SEED_FAKE_MAC}:${ID};${PREFIX};${GATEWAY};${SEARCH_DOMAIN};${DNS1};${VLAN};${BOND}" >> "${AI_STATIC_ADDRESSES_PATH}"
    done
    echo "192.168.1.109;24:41:8c:73:4f:6a;${PREFIX};192.168.1.1;${SEARCH_DOMAIN};8.8.8.8;false;false" >> "${AI_STATIC_ADDRESSES_PATH}"
    echo "10.19.115.219;ec:f4:bb:ed:5c:f8;23;10.19.115.254;e2e.bos.redhat.com;10.19.143.247;false;false" >> "${AI_STATIC_ADDRESSES_PATH}"

}

function env_vars() {
    ISO=discovery_image_ocp.iso
    SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
    IFCFG_TEMPLATE=${SCRIPTPATH}/ifcfg-template
    NMCON_TEMPLATE=${SCRIPTPATH}/nmcon-template
    IFCFG_IGN_TEMPLATE=${SCRIPTPATH}/ifcfg-ign-template
    NMCON_IGN_TEMPLATE=${SCRIPTPATH}/nmcon-ign-template
    AI_STATIC_ADDRESSES_PATH="/tmp/AI_STATIC_INV"
    AI_NM_CONN_TEMP_PATH="/tmp/AI_NMCONN_BASE"
    AI_IFCFG_TEMP_PATH="/tmp/AI_IFCFG_BASE"
    create_template_files
}

function create_template_files() {
    cat > ${AI_NM_CONN_TEMP_PATH} <<EOF
[connection]
id=\$FOUND_INTERFACE
interface-name=\$FOUND_INTERFACE
type=ethernet
multi-connect=3
autoconnect=yes
autoconnect-priority=1

[ethernet]
mac-address-blacklist=

[ipv4]
method=manual
addresses=\$FOUND_IP/\$FOUND_PREFIX
gateway=\$FOUND_GW
dns=\$FOUND_DNS
dns-search=\$FOUND_SE_DOMAIN

[ipv6]
addr-gen-mode=eui64
method=auto

[802-3-ethernet]
mac-address=\$FOUND_MAC
EOF

    cat > ${AI_IFCFG_TEMP_PATH} <<EOF
NAME=\$FOUND_INTERFACE
HWADDR=\$FOUND_MAC
DEVICE=\$FOUND_INTERFACE
TYPE=Ethernet
BOOTPROTO=static
IPADDR=\$FOUND_IP
PREFIX=\$FOUND_PREFIX
GATEWAY=\$FOUND_GW
DNS1=\$FOUND_DNS
DEFROUTE=yes
ONBOOT=yes
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
    export IFCFG_FILE="/etc/sysconfig/network-scripts/ifcfg-${FOUND_INTERFACE}"
    envsubst < ${AI_NM_CONN_TEMP_PATH} > ${NM_KEY_FILE}
    envsubst < ${AI_IFCFG_TEMP_PATH} > ${IFCFG_FILE}
    chmod 600 ${NM_KEY_FILE}
}

env_vars
generate_mock_file
correlate_int_mac
