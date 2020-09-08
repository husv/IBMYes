#!/bin/bash
SH_PATH=$(cd "$(dirname "$0")";pwd)
cd ${SH_PATH}

create_mainfest_file(){
    cat >  ${SH_PATH}/v2ray-cloudfoundry/manifest.yml  << EOF
applications:
- path: .
  name: ${IBM_APP_NAME}
  random-route: true
  memory: ${IBM_MEM_SIZE}M
EOF

    echo "下载已有配置..请稍等"
    ibmcloud cf ssh ${IBM_APP_NAME} -c "cat /home/vcap/app/v2ray/config.json" > config.json
    sed -i 1d config.json
    sed -i 1d config.json
    mv config.json ${SH_PATH}/v2ray-cloudfoundry/v2ray/
    echo "处理完毕，开始推送..."
}

init_and_clone_repo(){
    echo "进行初始化。。。"
    cd v2ray-cloudfoundry/v2ray
    # Upgrade V2Ray to the latest version
    rm v2ray v2ctl
    
    # Script from https://github.com/v2fly/fhs-install-v2ray/blob/master/install-release.sh
    # Get V2Ray release version number
    TMP_FILE="$(mktemp)"
    if ! curl -s -o "$TMP_FILE" 'https://api.github.com/repos/v2fly/v2ray-core/releases/latest'; then
        rm "$TMP_FILE"
        echo 'error: 获取最新V2Ray版本号失败。请重试'
        exit 1
    fi
    RELEASE_LATEST="$(sed 'y/,/\n/' "$TMP_FILE" | grep 'tag_name' | awk -F '"' '{print $4}')"
    rm "$TMP_FILE"
    echo "最新 V2Ray版本为 $RELEASE_LATEST"
    # Download latest release
    DOWNLOAD_LINK="https://github.com/v2fly/v2ray-core/releases/download/$RELEASE_LATEST/v2ray-linux-64.zip"
    if ! curl -s -L -H 'Cache-Control: no-cache' -o "latest-v2ray.zip" "$DOWNLOAD_LINK"; then
        echo 'error: 下载V2Ray失败，请重试'
        return 1
    fi
    unzip latest-v2ray.zip v2ray v2ctl geoip.dat geosite.dat
    rm latest-v2ray.zip
    
    chmod 0755 ./*
    cd ${SH_PATH}/v2ray-cloudfoundry
    echo "初始化完成。"
}

install(){
    echo "进行安装。。。"
    cd ${SH_PATH}/v2ray-cloudfoundry
    if [ -e "manifest.yml" -a -e "v2ray/v2ctl" -a -e "v2ray/v2ray" -a -e "v2ray/config.json" ]; then
        ibmcloud cf push
    else
        echo "关键文件缺失"
        exit 1
    fi
}

init_and_clone_repo
create_mainfest_file
install
