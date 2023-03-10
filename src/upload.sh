#!/bin/bash
# Upload ndjson file

PASSWORDFILE="/data/passwords"

#if [ `id -u` != "0" ]; then
#  echo "Got Root?"
#  exit 1
#fi

if [ "$#" != "2" ]; then
  echo "$0: <INDEX> <PCAPFILE>"
  exit 1
fi

if [ -z "${PASS}" ]; then
  echo "Set PASS in the environment!"
  echo "Use ${PASSWORDFILE} to find the password for elastic"
  exit 2
fi

HOST=${HOST:-localhost}
INDEX="$1"
PCAPFILE="$2"
if [ ! -r ${PCAPFILE} ]; then
  echo "${PCAPFILE} is not readable!"
  exit 3
fi

BASENAME=`basename ${PCAPFILE}`
NDJSONFILE=".${BASENAME}.ndjson"
tshark -r ${PCAPFILE} -T ek | ./ek2es7.exe >${NDJSONFILE}
curl -s -k -u elastic:${PASS} -XPOST http://${HOST}:9200/${INDEX}/_bulk?pretty\&refresh=true -H "Content-Type: application/x-ndjson" --data-binary @${NDJSONFILE} 2>&1
# curl -k -u elastic:${PASS} -XPOST http://${HOST}:9200/${INDEX}/_bulk?pretty\&refresh=true -H "Content-Type: application/x-ndjson" --data-binary @${NDJSONFILE}
# curl -k -u elastic:${PASS} -XGET  http://${HOST}:9200/${INDEX}/_search/?size=10\&pretty=true
rm ${NDJSONFILE}
