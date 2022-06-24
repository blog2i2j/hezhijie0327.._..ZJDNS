#!/bin/bash

# Parameter
OWNER="hezhijie0327"
REPO="mosdns"
TAG="latest"
DOCKER_PATH="/docker/mosdns"

## Function
# Get Latest Image
function GetLatestImage() {
    docker pull redis:latest && docker pull ${OWNER}/${REPO}:${TAG} && IMAGES=$(docker images -f "dangling=true" -q)
}
# Cleanup Current Container
function CleanupCurrentContainer() {
    if [ $(docker ps -a --format "table {{.Names}}" | grep -E "^redis$") ]; then
        docker stop redis && docker rm redis
    fi
    if [ $(docker ps -a --format "table {{.Names}}" | grep -E "^${REPO}$") ]; then
        docker stop ${REPO} && docker rm ${REPO}
    fi
}
# Download mosDNS Configuration
function DownloadmosDNSConfiguration() {
    curl -s --connect-timeout 15 "https://source.zhijie.online/CMA_DNS/main/mosdns/config.yaml" > "${DOCKER_PATH}/conf/config.yaml"
}
# Update GeoIP CN Rule
function UpdateGeoIPCNRule() {
    curl -s --connect-timeout 15 "https://source.zhijie.online/CNIPDb/main/cnipdb/country_ipv4_6.txt" > "${DOCKER_PATH}/data/GeoIP_CNIPDb.txt"
}
# Create New Container
function CreateNewContainer() {
    docker run --name redis --net host --restart=always \
        -v ${DOCKER_PATH}/data/redis:/data \
        -d redis:latest \
        --aof-use-rdb-preamble yes \
        --appendfsync everysec \
        --appendonly yes \
        --lazyfree-lazy-eviction yes \
        --lazyfree-lazy-expire yes \
        --lazyfree-lazy-server-del yes \
        --maxmemory 64MB \
        --maxmemory-policy allkeys-lru \
        --maxmemory-samples 10
    docker run --name ${REPO} --net host --restart=always \
        -v ${DOCKER_PATH}/conf:/etc/mosdns/conf \
        -v ${DOCKER_PATH}/data:/etc/mosdns/data \
        -d ${OWNER}/${REPO}:${TAG} \
        start \
        -c "/etc/mosdns/conf/config.yaml" \
        -d "/etc/mosdns/data"
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
# Call DownloadmosDNSConfiguration
DownloadmosDNSConfiguration
# Call UpdateGeoIPRule
UpdateGeoIPCNRule
# Call CleanupCurrentContainer
CleanupCurrentContainer
# Call CreateNewContainer
CreateNewContainer
# Call CleanupExpiredImage
CleanupExpiredImage
