#!/bin/bash

ISO=discovery_image_ocp.iso

sudo podman run --privileged --rm -v .:/data -w /data  quay.io/coreos/coreos-installer:release iso ignition show /data/$ISO > ignition.ign                                                                                                  
SCRIPT_IGN_JSON=$(cat script-ign)
SERVICE_IGN_JSON=$(cat systemd-unit-ign)
cat ignition.ign | jq ".storage.files += [${SCRIPT_IGN_JSON}]" > temp.ign
cat temp.ign | jq ".systemd.units += [${SERVICE_IGN_JSON}]" > new_ignition.ign
sudo podman run --privileged --rm -v .:/data -w /data  quay.io/coreos/coreos-installer:release iso ignition embed -f -i /data/new_ignition.ign -o /data/discovery_image_ocp_new.iso /data/$ISO                      
rm temp.ign
rm ignition.ign
rm new_ignition.ign
