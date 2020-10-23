#!/bin/bash

VM_NAME="ocp-master-"
LIBVIRT_PATH="/var/lib/libvirt/images"
ISO_NAME="discovery_image_ocp_master"

kcli delete vm ${VM_NAME}0 ${VM_NAME}1 ${VM_NAME}2 -y

for master in {0..2}
do
  rm -rf ${LIBVIRT_PATH}/${ISO_NAME}${master}.iso
  mv ${ISO_NAME}${master}.iso ${LIBVIRT_PATH}/${ISO_NAME}${master}.iso
done
virsh pool-refresh default

for master in {0..2}
do
  kcli create vm -P iso=${LIBVIRT_PATH}/${ISO_NAME}${master}.iso -P memory=20000 -P numcpus=4 -P disks=[120] ${VM_NAME}${master}
done
