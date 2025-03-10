#!/bin/bash

# Parameter
OWNER="hezhijie0327"
REPO="xray"
TAG="latest"
DOCKER_PATH="/docker/xray"

CURL_OPTION=""
DOWNLOAD_CONFIG="" # false, true
USE_CDN="true"

LOG_LEVEL="" # debug, info, warning, error, none

RUNNING_MODE="" # client, server
XHTTP_MODE="" # auto, packet-up, stream-one, stream-up

CNIPDB_SOURCE="" # bgp, dbip, geolite2, iana, ip2location, ipinfoio, ipipdotnet, iptoasn, vxlink, zjdb

CUSTOM_SERVERNAME="demo.zhijie.online" # demo.zhijie.online
CUSTOM_UUID="99235a6e-05d4-2afe-2990-5bc5cf1f5c52" # $(uuidgen | tr 'A-Z' 'a-z')

ENABLE_ENCRYPT_PATH="" #false, true
CUSTOM_ENCRYPT_SEED="$(date +%Y-%m-%W)" # YEAR-MONTH-WEEK

ENABLE_DNS="" # false, true
ENABLE_DNS_CACHE="" # false, true
CUSTOM_DNS=() # ("1.0.0.1@53" "223.5.5.5@53#CN" "8.8.8.8@53%1.1.1.1" "8.8.4.4@53%auto&AAAA")

CUSTOM_IP=() # ("1.0.0.1" "1.1.1.1" "127.0.0.1@7891")

SSL_CERT="fullchain.cer"
SSL_KEY="zhijie.online.key"

## Function
# Get WAN IP
function GetWANIP() {
    if [ "${Type}" == "A" ]; then
        IPv4_v6="4"
        IP_REGEX="^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}$"
    else
        IPv4_v6="6"
        IP_REGEX="^(([0-9a-f]{1,4}:){7,7}[0-9a-f]{1,4}|([0-9a-f]{1,4}:){1,7}:|([0-9a-f]{1,4}:){1,6}:[0-9a-f]{1,4}|([0-9a-f]{1,4}:){1,5}(:[0-9a-f]{1,4}){1,2}|([0-9a-f]{1,4}:){1,4}(:[0-9a-f]{1,4}){1,3}|([0-9a-f]{1,4}:){1,3}(:[0-9a-f]{1,4}){1,4}|([0-9a-f]{1,4}:){1,2}(:[0-9a-f]{1,4}){1,5}|[0-9a-f]{1,4}:((:[0-9a-f]{1,4}){1,6})|:((:[0-9a-f]{1,4}){1,7}|:)|fe80:(:[0-9a-f]{0,4}){0,4}%[0-9a-z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-f]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$"
    fi
    if [ "${StaticIP:-auto}" == "auto" ]; then
        IP_RESULT=$(curl -${IPv4_v6:-4} -s --connect-timeout 15 "https://api.cloudflare.com/cdn-cgi/trace" | grep "ip=" | sed "s/ip=//g" | grep -E "${IP_REGEX}")
        if [ "${IP_RESULT}" == "" ]; then
            IP_RESULT=$(curl -${IPv4_v6:-4} -s --connect-timeout 15 "https://api64.ipify.org" | grep -E "${IP_REGEX}")
            if [ "${IP_RESULT}" == "" ]; then
                IP_RESULT=$(dig -${IPv4_v6:-4} +short TXT @ns1.google.com o-o.myaddr.l.google.com | tr -d '"' | grep -E "${IP_REGEX}")
                if [ "${IP_RESULT}" == "" ]; then
                    IP_RESULT=$(dig -${IPv4_v6:-4} +short ANY @resolver1.opendns.com myip.opendns.com | grep -E "${IP_REGEX}")
                    if [ "${IP_RESULT}" == "" ]; then
                        echo "invalid"
                    else
                        echo "${IP_RESULT}"
                    fi
                else
                    echo "${IP_RESULT}"
                fi
            else
                echo "${IP_RESULT}"
            fi
        else
            echo "${IP_RESULT}"
        fi
    else
        if [ "$(echo ${StaticIP} | grep ',')" != "" ]; then
            if [ "${Type}" == "A" ]; then
                IP_RESULT=$(echo "${StaticIP}" | cut -d ',' -f 1 | grep -E "${IP_REGEX}")
            else
                IP_RESULT=$(echo "${StaticIP}" | cut -d ',' -f 2 | grep -E "${IP_REGEX}")
            fi
            if [ "${IP_RESULT}" == "" ]; then
                echo "invalid"
            else
                echo "${IP_RESULT}"
            fi
        else
            IP_RESULT=$(echo "${StaticIP}" | grep -E "${IP_REGEX}")
            if [ "${IP_RESULT}" == "" ]; then
                echo "invalid"
            else
                echo "${IP_RESULT}"
            fi
        fi
    fi
}
# Get Latest Image
function GetLatestImage() {
    docker pull ${OWNER}/${REPO}:${TAG} && IMAGES=$(docker images -f "dangling=true" -q)
}
# Cleanup Current Container
function CleanupCurrentContainer() {
    if [ $(docker ps -a --format "table {{.Names}}" | grep -E "^${REPO}$") ]; then
        docker stop ${REPO} && docker rm ${REPO}
    fi
}
# Download Configuration
function DownloadConfiguration() {
    if [ "${USE_CDN}" == "true" ]; then
        CDN_PATH="source.zhijie.online"
    else
        CDN_PATH="raw.githubusercontent.com/hezhijie0327"
    fi

    if [ ! -d "${DOCKER_PATH}/conf" ]; then
        mkdir -p "${DOCKER_PATH}/conf"
    fi

    if [ "${DOWNLOAD_CONFIG:-true}" == "true" ]; then
        curl ${CURL_OPTION:--4 -s --connect-timeout 15} "https://${CDN_PATH}/ZJDNS/main/xray/${RUNNING_MODE:-server}.json" > "${DOCKER_PATH}/conf/config.json" && sed -i "s/\"info\"/\"${LOG_LEVEL:-info}\"/g;s/\[ \"h2\" \]/\[ \"${CUSTOM_ALPN_VERSION:-h2}\" \]/g;s/demo.zhijie.online/${CUSTOM_SERVERNAME}/g;s/99235a6e-05d4-2afe-2990-5bc5cf1f5c52/${CUSTOM_UUID}/g;s/fullchain\.cer/${SSL_CERT/./\\.}/g;s/zhijie\.online\.key/${SSL_KEY/./\\.}/g" "${DOCKER_PATH}/conf/config.json"

        if [ "${XHTTP_MODE:-auto}" != "auto" ]; then
            sed -i "s|packet-up|${XHTTP_MODE}|g" "${DOCKER_PATH}/conf/config.json"
        fi

        if [ "${ENABLE_ENCRYPT_PATH:-false}" != "false" ]; then
            CUSTOM_ENCRYPT_SEED=$(echo -n "ffffffff-ffff-ffff-ffff-ffffffffffff${CUSTOM_ENCRYPT_SEED}" | sha1sum | awk '{print substr($1, 1, 8) "-" substr($1, 9, 4) "-" "5" substr($1, 14, 3) "-" substr($1, 17, 4) "-" substr($1, 21, 12)}')

            sed -i "s|XHTTP4VLESS|$(echo -n ${CUSTOM_ENCRYPT_SEED}XHTTP4VLESS${CUSTOM_UUID} | base64 | sha256sum | awk '{print $1}')|g" "${DOCKER_PATH}/conf/config.json"
        fi

        if [ "${ENABLE_DNS_CACHE:-false}" != "false" ]; then
            sed -i 's/"disableCache": true/"disableCache": false/g' "${DOCKER_PATH}/conf/config.json"
        fi

        if [ "${CUSTOM_DNS[*]}" != "" ]; then
            JSON_STRING="" && for IP in "${CUSTOM_DNS[@]}"; do
                IPADDR="" && IPADDR=$(echo ${IP} | cut -d "@" -f 1)
                PORT="" && PORT=$(echo ${IP} | grep '@' | cut -d "@" -f 2 | cut -d "#" -f 1 | cut -d "%" -f 1 | cut -d "&" -f 1)
                EXPECT="" && EXPECT=$(echo ${IP} | grep '#' | cut -d "#" -f 2 | cut -d "%" -f 1 | cut -d "&" -f 1)
                CLIENT="" && CLIENT=$(echo ${IP} | grep '%' | cut -d "%" -f 2 | cut -d "&" -f 1)
                TYPE="" && TYPE=$(echo ${IP} | grep '&' | cut -d "&" -f 2)

                ADDITIONAL="" && if [ "${CLIENT}" != "" ]; then
                    ADDITIONAL=', "clientIp": "'$(StaticIP=${CLIENT} && Type=${TYPE:-A} && GetWANIP)'"'
                fi

                if [ "${EXPECT}" != "" ]; then
                    if [ "${EXPECT}" == "CN" ]; then
                        JSON_STRING+='{ "address": "'${IPADDR}'", "port": '${PORT:-53}''${ADDITIONAL}', "expectIPs": [ "ext:/etc/xray/data/geoip.dat:cn" ] }, '
                    else
                        JSON_STRING+='{ "address": "'${IPADDR}'", "port": '${PORT:-53}''${ADDITIONAL}', "expectIPs": [ "ext:/etc/xray/data/geoip.dat:!cn" ] }, '
                    fi
                else
                    JSON_STRING+='{ "address": "'${IPADDR}'", "port": '${PORT:-53}''${ADDITIONAL}' }, '
                fi
            done && JSON_STRING="${JSON_STRING%, }"

            sed -i "s|{ \"address\": \"127.0.0.1\", \"port\": 53 }|${JSON_STRING}|g" "${DOCKER_PATH}/conf/config.json"
        fi

        if [ "${CUSTOM_IP[*]}" != "" ] && [ "${RUNNING_MODE:-server}" == "client" ]; then
            JSON_STRING="" && for IP in "${CUSTOM_IP[@]}"; do
                if [ -z "$(echo "${IP}" | grep "@")" ]; then
                    PORT="443"
                else
                    PORT=$(echo ${IP} | cut -d "@" -f 2)
                    IP=$(echo ${IP} | cut -d "@" -f 1)
                fi

                JSON_STRING+='{ "address": "'${IP}'", "port": '${PORT}', "users": [ { "encryption": "none", "id": "'${CUSTOM_UUID}'" } ] }, '
            done && JSON_STRING="${JSON_STRING%, }"

            sed -i "s/{ \"address\": \"${CUSTOM_SERVERNAME}\", \"port\": 443, \"users\": \\[ { \"encryption\": \"none\", \"id\": \"${CUSTOM_UUID}\" } \\] }/${JSON_STRING}/g" "${DOCKER_PATH}/conf/config.json"
        fi
    fi

    if [ "${ENABLE_DNS:-true}" != "true" ]; then
        cat "${DOCKER_PATH}/conf/config.json" | jq 'del(.dns)' > "${DOCKER_PATH}/conf/config.json.tmp" && mv "${DOCKER_PATH}/conf/config.json.tmp" "${DOCKER_PATH}/conf/config.json"
    fi

    if [ ! -d "${DOCKER_PATH}/data" ]; then
        mkdir -p "${DOCKER_PATH}/data"
    fi && curl ${CURL_OPTION:--4 -s --connect-timeout 15} "https://${CDN_PATH}/CNIPDb/main/cnipdb_${CNIPDB_SOURCE:-geolite2}/country_ipv4_6.dat" > "${DOCKER_PATH}/data/geoip.dat"
}
# Create New Container
function CreateNewContainer() {
    docker run --name ${REPO} --net host --restart=always \
        --privileged \
        -v /docker/ssl:/etc/xray/cert:ro \
        -v ${DOCKER_PATH}/conf:/etc/xray/conf \
        -v ${DOCKER_PATH}/data:/etc/xray/data \
        -d ${OWNER}/${REPO}:${TAG} \
        run \
        -c /etc/xray/conf/config.json
}
# Cleanup Expired Image
function CleanupExpiredImage() {
    if [ "${IMAGES}" != "" ]; then
        docker rmi ${IMAGES}
    fi
}

## Process
# Call GetLatestImage
GetLatestImage
# Call CleanupCurrentContainer
CleanupCurrentContainer
# Call DownloadConfiguration
DownloadConfiguration
# Call CreateNewContainer
CreateNewContainer
# Call CleanupExpiredImage
CleanupExpiredImage
