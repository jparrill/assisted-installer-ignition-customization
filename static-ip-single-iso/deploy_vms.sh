#!/bin/bash

VM_NAME="ocp-master-"
LIBVIRT_PATH="/var/lib/libvirt/images"
ISO_NAME="discovery_image_ocp"

kcli delete vm ${VM_NAME}3 ${VM_NAME}1 ${VM_NAME}2 -y

rm -rf ${LIBVIRT_PATH}/${ISO_NAME}${master}.iso
mv ${ISO_NAME}_new.iso ${LIBVIRT_PATH}/
virsh pool-refresh default

kcli create vm -P nets=['{"name":"default","mac":"de:ad:be:ef:00:11"}'] -P iso=${LIBVIRT_PATH}/${ISO_NAME}_new.iso -P memory=20000 -P numcpus=4 -P disks=[120] ${VM_NAME}1
kcli create vm -P nets=['{"name":"default","mac":"de:ad:be:ef:00:22"}'] -P iso=${LIBVIRT_PATH}/${ISO_NAME}_new.iso -P memory=20000 -P numcpus=4 -P disks=[120] ${VM_NAME}2
kcli create vm -P nets=['{"name":"default","mac":"de:ad:be:ef:00:33"}'] -P iso=${LIBVIRT_PATH}/${ISO_NAME}_new.iso -P memory=20000 -P numcpus=4 -P disks=[120] ${VM_NAME}3
