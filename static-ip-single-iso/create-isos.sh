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
    echo > "${AI_STATIC_ADDRESSES_PATH}"

    for ID in {10..99} 
    do
        echo "${SEED_FAKE_IP}.${ID};${SEED_FAKE_MAC}:${ID};${PREFIX};${GATEWAY};${SEARCH_DOMAIN};${DNS1}" >> "${AI_STATIC_ADDRESSES_PATH}"
    done
    echo "192.168.1.109;24:41:8c:73:4f:6a;${PREFIX};192.168.1.1;${SEARCH_DOMAIN};8.8.8.8" >> "${AI_STATIC_ADDRESSES_PATH}"

}

function env_vars() {
    ISO=discovery_image_ocp.iso
    SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
    IFCFG_TEMPLATE=${SCRIPTPATH}/ifcfg-template
    NMCON_TEMPLATE=${SCRIPTPATH}/nmcon-template
    IFCFG_IGN_TEMPLATE=${SCRIPTPATH}/ifcfg-ign-template
    NMCON_IGN_TEMPLATE=${SCRIPTPATH}/nmcon-ign-template
    AI_STATIC_ADDRESSES_PATH="/tmp/AI_STATIC_INV"
}

function find_my_mac() {
    MAC_TO_CHECK=${1}

    for entry in $(cat ${AI_STATIC_ADDRESSES_PATH})
    do
        MAC=$(echo ${entry} | cut -f2 -d\;)
        if [[ ! -z ${MAC} ]] && [[ -z ${FOUND_MAC} ]]; then
            if [[ "${MAC}" == "${MAC_TO_CHECK}" ]]; then
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
        echo "Host MAC ${MAC_TO_CHECK} not found in the list"
    fi
}

function correlate_int_mac() {
    # Correlate the Mac with the interface
    for INTERFACE in $(find /sys/class/net -mindepth 1 -maxdepth 1 ! -name lo -printf "%P\n")
    do
        INT_MAC=$(cat /sys/class/net/${INTERFACE}/address)
        if [[ ! -z ${INT_MAC} ]]; then
            echo "MAC to check: ${INT_MAC}"
            find_my_mac ${INT_MAC}
            if [[ "${FOUND_MAC}" == "${INT_MAC}" ]];then
                export FOUND_INT=${INTERFACE}
                echo "MAC Found in the list, this is the Net data: "
                echo "MAC: ${FOUND_MAC}"
                echo "IP: ${FOUND_IP}"
                echo "MASK: ${FOUND_PREFIX}"
                echo "GW: ${FOUND_GW}"
                echo "SEARCH DOMAIN: ${FOUND_SE_DOMAIN}"
                echo "DNS: ${FOUND_DNS}"
                break
            fi
        fi
    done

    if [[ -z ${FOUND_INT} ]];then
        echo "Interface with MAC ${INT_MAC} address ${INT_MAC} not found"
        exit 1
    fi

    export NM_KEY_FILE="/etc/NetworkManager/system-connections/${FOUND_INT}.nmconnection"
    export IFCFG_FILE="/etc/sysconfig/network-scripts/ifcfg-${FOUND_INT}"
}

env_vars
generate_mock_file
correlate_int_mac

#for master in {1..3}
#do
#    IFCFG_BASE64=$(envsubst < $IFCFG_TEMPLATE | base64 -w0)
#    NMCON_BASE64=$(envsubst < $NMCON_TEMPLATE | base64 -w0)
#    AI_MOCK_STATIC_INV=$(cat ${tmpFile} | base64 -w0)
#    
#
#
#    echo "lol"
#    #sudo podman run --privileged --rm -v .:/data -w /data  quay.io/coreos/coreos-installer:release iso ignition show /data/$ISO > ignition.ign
#    #IFCFG_IGN_JSON=$(sed "s/IFCFG_BASE64/$IFCFG_BASE64/" $IFCFG_IGN_TEMPLATE)
#    #NMCON_IGN_JSON=$(sed "s/NMCON_BASE64/$NMCON_BASE64/" $NMCON_IGN_TEMPLATE)
#    #cat ignition.ign | jq ".storage.files += [${IFCFG_IGN_JSON}]" > temp.ign
#    #sleep 2
#    #cat temp.ign | jq ".storage.files += [${NMCON_IGN_JSON}]" > master${master}_ignition.ign
#    #sudo podman run --privileged --rm -v .:/data -w /data  quay.io/coreos/coreos-installer:release iso ignition embed -f -i /data/master${master}_ignition.ign -o /data/discovery_image_ocp_master${master}.iso /data/$ISO
#    #rm temp.ign
#    #rm ignition.ign
#    #rm master${master}_ignition.ign
#done
