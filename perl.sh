TEMP_CFG_FILE=/home/mattcloutier/Documents/bash/text.txt

GET_IMEI="$(grep 'modemInfoIMEI:' ${TEMP_CFG_FILE} )-config.txt"

SIMPLE_IMEI="$(echo -e "${GET_IMEI}" | tr -d '\r' )"

echo ${SIMPLE_IMEI} | grep -o -P '(\d+)'
