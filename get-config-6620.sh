#!/bin/sh
# 
# REQUIRES: gawk
#
# May need for redirects on Ubuntu
# /etc/hosts 
#    192.168.0.1 my.jetpack
# /etc/resolv.conf 
#    nameserver 192.168.0.1
#
#
# curl -c cookie2 -o output2.txt --trace-ascii trace2.txt http://192.168.0.1/login
# parse the web page in output2.txt for gSecureToken, aka secToken
# ex. gSecureToken : "a665d7bd68c30de9b51e60109edd600b630a084a"
#
# shaPassword is sha1sum of: Admin Password concat. w/ Secure Token
# ex. echo -n "**********a665d7bd68c30de9b51e60109edd600b630a084a" | sha1sum
#     1f0085d995e0a73d69c76b792fc67c2b2c4cb803  -
#     shaPassword=1f0085d995e0a73d69c76b792fc67c2b2c4cb803
#
# inputPassword is 1st part of gSecureToken, admin password length long, for * display purposes
#
# Note: Referrer and redirectLocation may need to match
#
# curl -b cookie2 -o output3.txt -d shaPassword=1f0085d995e0a73d69c76b792fc67c2b2c4cb803 -d gSecureToken=a665d7bd68c30de9b51e60109edd600b630a084a -d redirectLocation=%2F -d inputPassword=a665d7bd68 http://192.168.0.1/login
# curl -b cookie-login.txt -o login-out.txt --trace-ascii login-trace.txt -d shaPassword=d8505572af2968842e54cb4d1e47434d92d42b33 -d gSecureToken=1ab8c12f50b69a19feae8dee88535936a96c76c4 -d redirectLocation=%2F -d inputPassword=1ab8c12f50 http://192.168.0.1/login

if [ $# -eq 1 ]; then
   echo "Unconfigured hotspot admin password provided, assuming IP Address is 192.168.1.1 too!"
   ADMIN_PASS="${1}"
   BASE_URL="http://192.168.1.1/"
else
   # V3 Configured address and password
   BASE_URL="http://192.168.0.1/"
   ADMIN_PASS="**************"
fi

# Create directory for temporary files
TIME_STAMP="$(date +%Y%m%d%H%M%S)"
TEMP_PATH="/tmp/${TIME_STAMP}/"
test -d $TEMP_PATH || mkdir -p $TEMP_PATH

# Create temporary file suffix
SUFFIX_HTML="-6620.html"
COOKIE="${TEMP_PATH}cookie"
TEMP_CFG_FILE="${TEMP_PATH}config-6620.txt"
ERR_LOG="${TEMP_PATH}error.log"
PRE_LOGIN_INDEX="${TEMP_PATH}login-pre${SUFFIX_HTML}"
POST_LOGIN_INDEX="${TEMP_PATH}login-post${SUFFIX_HTML}"

echo
echo "Retrieving Configuration from Verizon 6620 Hotspot"
echo

# GET SECURE TOKEN
curl -c ${COOKIE} -o ${PRE_LOGIN_INDEX} ${BASE_URL}login

if [ -s ${PRE_LOGIN_INDEX} ]; then
   echo
   echo ${PRE_LOGIN_INDEX}
   echo
else
   echo
   echo "Failure Connecting to Hotspot!"
   echo
   echo "If you are having trouble talking to the hotspot:"
   echo "   First power cycle hotspot, especially if you just configured it. If that doesn't work:"
   echo "   You may need to add ${BASE_URL}   my.jetpack to /etc/hosts"
   echo "   You may need to change the 1st nameserver to ${BASE_URL} in /etc/resolv.conf"
   echo
   exit 1
fi

TOKEN="$(gawk -F'gSecureToken : \"' '{ print $2 }' ${PRE_LOGIN_INDEX} | gawk -F'"' '{ print $1 }'| tr -d '[:space:]')"
echo "gSecuretoken=${TOKEN}"

PASSWD="$(echo "${ADMIN_PASS}${TOKEN}")"
echo "PASSWORD=${PASSWD}"

SHA_PASSWD="$(echo -n "${PASSWD}" | sha1sum | gawk -F' ' '{ print $1 }')"
echo "SHA1 PASSWORD=${SHA_PASSWD}"

INPUT_PASSWD="$(echo "${TOKEN}" | gawk '{ printf "%.10s", $1 }')"
echo "Substitute Password=${INPUT_PASSWD}"
echo

# LOGIN
curl -s -b ${COOKIE} -o ${POST_LOGIN_INDEX} --referer ${BASE_URL}login -d shaPassword=$SHA_PASSWD -d gSecureToken=$TOKEN -d redirectLocation=%2F -d inputPassword=$INPUT_PASSWD ${BASE_URL}login

# GET MAKE, MODEL, SW VERSION, IMEI, etc
for web_page in jetpackinfo diagnostics ; do
   SECTION_HDR="$(echo "${web_page}" | tr '[:lower:]' '[:upper:]') ******************************************"
   WEBPAGE="${TEMP_PATH}$web_page${SUFFIX_HTML}"
   echo "${SECTION_HDR}"
   curl -s -b ${COOKIE} -o ${WEBPAGE} ${BASE_URL}$web_page
   echo "${SECTION_HDR}" >> ${TEMP_CFG_FILE}
   xmllint --html --noblanks --xpath '//div[@class="col input"]' ${WEBPAGE} 2>>${ERR_LOG} | tr -d -s '\n\r\f\t' '  ' | sed 's/\n//g; s/<div class=\"col input\" id=\"//g; s/\">/:\t/g; s/<\/div>/\n/g' >> ${TEMP_CFG_FILE}
   echo "\n" >> ${TEMP_CFG_FILE}
done

# LOOP THROUGH PAGES GETTING SETTINGS
for web_page in adminpassword connecteddevices devicelist firewall gps lan logs macfilter networks parentalcontrols portfiltering portforwarding preferences sim sitelist wifi ; do
   SECTION_HDR="$(echo "${web_page}" | tr '[:lower:]' '[:upper:]') ******************************************"
   WEBPAGE="${TEMP_PATH}$web_page${SUFFIX_HTML}"
   echo "${SECTION_HDR}"
   curl -s -b ${COOKIE} -o ${WEBPAGE} ${BASE_URL}$web_page
   echo "${SECTION_HDR}" >> ${TEMP_CFG_FILE}
   xmllint --html --noblanks --xpath '//select' ${WEBPAGE} 2>>${ERR_LOG} | sed 's/<\/select>/\n/g; s/<option/\n\t&/g' >> ${TEMP_CFG_FILE}
   xmllint --html --noblanks --xpath '//input'  ${WEBPAGE} 2>>${ERR_LOG} | sed 's/<input/\n&/g;' >> ${TEMP_CFG_FILE}
   echo "\n" >> ${TEMP_CFG_FILE}
done
echo

# LOGOUT! - Can only have 1 logged in user at a time
curl -s -b ${COOKIE} -o "${TEMP_PATH}logout${SUFFIX_HTML}" ${BASE_URL}logout

# Find IMEI to create filename
OUTPUT_FILE="$(grep 'modemInfoIMEI:' ${TEMP_CFG_FILE} | awk -F' ' '{print $2}')-config.txt"
if [ -e ${OUTPUT_FILE} ]; then
   echo "${OUTPUT_FILE} ALREADY EXISTS!!!"
   OUTPUT_FILE=${OUTPUT_FILE}.${TIME_STAMP}
   echo "Saving to alternate file: ${OUTPUT_FILE}"
   echo "Rename file for new customer!!!"
else
   echo "Saving to file: ${OUTPUT_FILE}"
fi

# Remove secure token which changes every login
grep -v gSecureToken ${TEMP_CFG_FILE} >${OUTPUT_FILE}

kompare default-config-6620.txt ${OUTPUT_FILE} 2>>${ERR_LOG}

MAC_ADDRESS="$(xmllint --html --noblanks --xpath '//div[@id="macAddress"]/text()' ${TEMP_PATH}lan${SUFFIX_HTML} 2>>${ERR_LOG} | tr -d -s '\n\r\f\t' '')"
echo
echo "Record Mac Address: ${MAC_ADDRESS}"
echo

exit

# Jason object for home page status info including battery, session duration/usage, signal bars, etc
# curl -v http://192.168.0.1/srv/status
# 291's pretty print can be used to look at easier

#xmllint --html --noblanks --xpath '//select' preferences | sed 's/<\/select>/&\n/g; s/<option/&\n\t/g'
#./adminpassword/index.html
./advanced/index.html
./backup/index.html
#./connecteddevices/index.html
./datausage/index.html
#./devicelist/index.html
#./diagnostics/index.html
#./firewall/index.html
#./gps/index.html
./index.html
./internet/index.html
./jetpackinfo/index.html
#./lan/index.html
./login/index.html
./logout/index.html
#./logs/index.html
#./macfilter/index.html
#./manualdns/index.html
./messages/index.html
#./networks/index.html
#./parentalcontrols/index.html
#./portfiltering/index.html
#./portforwarding/index.html
#./preferences/index.html
#./sim/index.html
#./sitelist/index.html
#./softwareupdate/index.html
DC ./support/index.html
#./wifi/index.html

