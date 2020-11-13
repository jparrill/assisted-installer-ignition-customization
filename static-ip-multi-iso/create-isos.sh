#!/bin/bash

export NETMASK=255.255.255.0
export PREFIX=24
export GATEWAY=192.168.122.1
export SEARCH_DOMAIN=e2e.bos.redhat.com
export DNS1=192.168.122.1
export DNS2=8.8.8.8

ISO=rhcos_ocp.iso
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
IFCFG_TEMPLATE=${SCRIPTPATH}/ifcfg-template
NMCON_TEMPLATE=${SCRIPTPATH}/nmcon-template
IFCFG_IGN_TEMPLATE=${SCRIPTPATH}/ifcfg-ign-template
NMCON_IGN_TEMPLATE=${SCRIPTPATH}/nmcon-ign-template

for master in {0..2}
do
  export IP=192.168.122.1${master}
  IFCFG_BASE64=$(envsubst < $IFCFG_TEMPLATE | base64 -w0)
  NMCON_BASE64=$(envsubst < $NMCON_TEMPLATE | base64 -w0)
  sudo podman run --privileged --rm -v .:/data -w /data  quay.io/coreos/coreos-installer:release iso ignition show /data/$ISO > ignition.ign
  IFCFG_IGN_JSON=$(sed "s/IFCFG_BASE64/$IFCFG_BASE64/" $IFCFG_IGN_TEMPLATE)
  NMCON_IGN_JSON=$(sed "s/NMCON_BASE64/$NMCON_BASE64/" $NMCON_IGN_TEMPLATE)
  cat ignition.ign | jq ".storage.files += [${IFCFG_IGN_JSON}]" > temp.ign
  sleep 2
  cat temp.ign | jq ".storage.files += [${NMCON_IGN_JSON}]" > master${master}_ignition.ign
  sudo podman run --privileged --rm -v .:/data -w /data  quay.io/coreos/coreos-installer:release iso ignition embed -f -i /data/master${master}_ignition.ign -o /data/discovery_image_ocp_master${master}.iso /data/$ISO
  rm temp.ign
  rm ignition.ign
  rm master${master}_ignition.ign
done
