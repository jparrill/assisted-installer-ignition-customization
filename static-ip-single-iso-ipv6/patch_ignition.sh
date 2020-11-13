#!/bin/bash

NODE_IGN=${1}
ISO=rhcos_live.iso
CUSTOM_ISO=$(basename ${NODE_IGN})_custom.iso
SCRIPT_IGN_JSON=$(cat script-ign)
SERVICE_IGN_JSON=$(cat systemd-unit-ign)
cat ignition.ign | jq ".storage.files += [${SCRIPT_IGN_JSON}]" > temp.ign
cat temp.ign | jq ".systemd.units += [${SERVICE_IGN_JSON}]" > new_ignition.ign
sudo podman run --privileged --rm -v .:/data -w /data  quay.io/coreos/coreos-installer:release iso ignition embed -f -i /data/new_ignition.ign -o /data/${CUSTOM_ISO} /data/${ISO} 
rm temp.ign
rm ignition.ign
rm new_ignition.ign
