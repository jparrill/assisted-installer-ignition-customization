#!/bin/bash

CSV_FILE=${1}
CSV_DEST=/tmp/AI_STATIC_INV
IGN_FILE=./csv-inventory.ign

if [ -z $CSV_FILE ]
then
  echo "You need to provide a CSV inventory file"
  exit 1
fi
echo "Generating ignition file using $CSV_FILE inventory file"
CSV_BASE_64=$(openssl base64 -A -in ${CSV_FILE})
cat <<EOF > $IGN_FILE
{"overwrite": true,"path": "${CSV_DEST}","mode": 292,"user": {"name": "root"},"contents": { "source": "data:;base64,${CSV_BASE_64}"}}
EOF
echo "Ignition file generated at ${IGN_FILE}"
