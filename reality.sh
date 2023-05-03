#!/usr/bin/env bash
#
# A convenient script for generating and starting VLESS-XTLS-uTLS-REALITY configs.

LOGGER="XRAY-REALITY-SCRIPT"

BLACK="\033[0;30m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
WHITE="\033[0;37m"
BGREEN="\033[1;32m"
BRED="\033[1;31m"
RESET="\033[0m"

SCRIPT="$0"
CURDIR="$(dirname $0)"
XRAY_ORIG_CONFIG="/usr/local/etc/xray/config.json"
TEMPL_CONFIG="$CURDIR/configs/config.json"
CONFIG="$CURDIR/config.json"

URL_FILE="$CURDIR/url.txt"

trap "DIE" SIGHUP SIGINT SIGQUIT SIGABRT

function DIE() {
    CURDATE="${BLUE}$(date +'%Y-%m-%d %T')${RESET}"
    LOGLEVEL="${BRED}CRITICAL${RESET}"
    LOGMSG="the script is exiting"
    echo -e "$CURDATE $LOGGER $LOGLEVEL: $LOGMSG"
    sleep 1
    exit 1
}

function LOG() {
    CURDATE="${BLUE}$(date +'%Y-%m-%d %T')${RESET}"

    case $1 in
        "DEBUG")
            shift
            LOGLEVEL="${GREEN}  DEBUG${RESET}"
            LOGMSG="$1"
            echo -e "$CURDATE $LOGGER $LOGLEVEL: $LOGMSG"
            ;;
        "INFO")
            shift
            LOGLEVEL="${CYAN}   INFO${RESET}"
            LOGMSG="$1"
            echo -e "$CURDATE $LOGGER $LOGLEVEL: $LOGMSG"
            ;;
        "WARNING")
            shift
            LOGLEVEL="${YELLOW}WARNING${RESET}"
            LOGMSG="$1"
            echo -e "$CURDATE $LOGGER $LOGLEVEL: $LOGMSG"
            ;;
        "ERROR")
            shift
            LOGLEVEL="${RED}  ERROR${RESET}"
            LOGMSG="$1"
            echo -e "$CURDATE $LOGGER $LOGLEVEL: $LOGMSG"
            DIE
            ;;
        "CRITICAL")
            shift
            LOGLEVEL="${BRED}CRITICAL${RESET}"
            LOGMSG="$1"
            echo -e "$CURDATE $LOGGER $LOGLEVEL: $LOGMSG"
            DIE
            ;;
        *)
            LOGLEVEL="${WHITE}NOLEVEL${RESET}"
            LOGMSG="$1"
            echo -e "$CURDATE $LOGGER $LOGLEVEL: $LOGMSG"
            ;;
    esac
}

function usage_msg() {
    echo "Usage: $SCRIPT {init (Default) | config [--url (Default) | --qrencode] | update | --help | -h}"
    echo ""
    echo "init:   Default, install, update required packages, generate a config, and start xray"
    echo "config [--url | --qrencode]: generate a new config based on a template config"
    echo "        --url: print to terminal the VLESS url"
    echo "        --qrencode: print the url and also the QR encoded version to terminal"
    echo "update: update the required packages, including xray-core"
    echo "--help | -h: print this help message"
    echo ""
}

function sanity_checks() {
    LOG INFO "checking system requirements"
    [ "$EUID" -eq 0 ] || LOG ERROR "must have root access to run the script!"
    if ! command -v systemctl &>/dev/null; then
        LOG CRITICAL "systemd must be enabled as the init system!"
    fi
}

function install_pkgs() {
    LOG INFO "updating & upgrading system"
    apt update -y && apt upgrade -y

    pkgs=("openssl" "qrencode" "jq" "curl" "xclip")

    for pkg in ${pkgs[@]}; do
        LOG INFO "installing package: $pkg"
        apt install -y $pkg
    done

    LOG DEBUG "installing latest beta version of xray"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --beta
    LOG DEBUG "testing xray-core version"
    xray --version
    [ $? -ne 0 ] && LOG CRITICAL "something went wrong with xray core!"
}

function xray_new_config() {
    LOG DEBUG "generating uuid"
    uuid=$(xray uuid)
    LOG INFO "setting uuid: ${uuid}"

    LOG DEBUG "generating X25519 private and public key pairs"
    keys=$(xray x25519)
    private_key=$(echo $keys | cut -d " " -f 3)
    LOG INFO "setting private key: ${private_key}"
    public_key=$(echo $keys | cut -d " " -f 6)
    LOG INFO "setting public key: ${public_key}"

    LOG DEBUG "generating short id"
    short_id=$(openssl rand -hex 4)
    LOG INFO "setting short id: ${short_id}"
    
    LOG DEBUG "resolving public ip"
    public_ip=$(curl -s ifconfig.me)
    LOG INFO "setting public ip: ${public_ip}"

    cmfgsite="tgju.org"
    LOG INFO "using camouflag website: ${cmfgsite}"

    flow="xtls-rprx-vision"
    LOG INFO "using flow: ${flow}"

    inbound_port="49649"
    LOG INFO "setting inbound listen port: ${inbound_port}"

    protocol_type="tcp"
    LOG INFO "using ${protocol_type}"

    security="reality"
    LOG INFO "setting security: ${security}"

    fingerprint="chrome"
    LOG INFO "using fingerprint: ${fingerprint}"

    random_string=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 4; echo '')
    name="$security-$random_string"
    LOG INFO "setting name of the profile: ${name}"

    LOG DEBUG "using template config file: ${TEMPL_CONFIG}"
    cp "$TEMPL_CONFIG" "$CONFIG"

    LOG DEBUG "populating config.json file"
    cat <<< $(jq --arg uuid  $uuid '.inbounds[1].settings.clients[0].id = $uuid' "$CONFIG") > "$CONFIG"
    cat <<< $(jq --arg public_key  $public_key '.inbounds[1].streamSettings.realitySettings.publicKey = $public_key' "$CONFIG") > "$CONFIG"
    cat <<< $(jq --arg private_key $private_key '.inbounds[1].streamSettings.realitySettings.privateKey = $private_key' "$CONFIG") > "$CONFIG"
    cat <<< $(jq --arg short_id  $short_id '.inbounds[1].streamSettings.realitySettings.shortIds = [$short_id]' "$CONFIG") > "$CONFIG"


    case "$1" in
        "--url" | "")
            LOG INFO "generating url"
            url="vless://$uuid@$public_ip:$inbound_port?type=$protocol_type&security=$security&sni=$cmfgsite&pbk=$public_key&flow=$flow&sid=$short_id&fp=$fingerprint#$name"
            echo $url
            LOG INFO "saving url to: ${URL_FILE}"
            echo $url > ${URL_FILE}
            copy_config
            ;;
        "--qrencode")
            LOG INFO "generating url"
            url="vless://$uuid@$public_ip:$inbound_port?type=$protocol_type&security=$security&sni=$cmfgsite&pbk=$public_key&flow=$flow&sid=$short_id&fp=$fingerprint#$name"
            echo $url
            LOG INFO "saving url to: ${URL_FILE}"
            echo $url > ${URL_FILE}

            LOG DEBUG "generating qr encoding of the url"
            qrencode -t ANSIUTF8 $url
            copy_config
            ;;
        *)
            usage_msg
            ;;
    esac
}

function copy_config() {
    LOG INFO "backing up $XRAY_ORIG_CONFIG and replacing it with new config"
    xray_orig_config_dir=$(dirname $XRAY_ORIG_CONFIG)
    [ -f "$xray_orig_config_dir/config.json.old"  ] && LOG WARNING "$xray_orig_config_dir/config.json.old exists, replacing"
    mv "$XRAY_ORIG_CONFIG" "$xray_orig_config_dir/config.json.old"
    cp $CONFIG "$xray_orig_config_dir"
}

function xray_run() {
    copy_config

    if ! systemctl is-enabled --quiet xray.service; then
        LOG DEBUG "xray.service is not enabled, enabling now"
        systemctl enable xray.service
        [ $? -ne 0 ] && LOG CRITICAL "something went wrong when enabling xray.service"
    fi

    if ! systemctl is-active --quiet xray.service; then
        LOG DEBUG "xray.service is not running, starting now"
        systemctl start xray.service
        [ $? -ne 0 ] && LOG CRITICAL "something went wrong when starting xray.service"
    else
        LOG DEBUG "xray.service is already running, restarting"
        systemctl restart xray.service
        [ $? -ne 0 ] && LOG CRITICAL "something went wrong when restarting xray.service"
    fi

    LOG DEBUG "checking status on xray.service"
    systemctl status xray.service
    [ $? -ne 0 ] && LOG CRITICAL "something has went wrong with xray.service, status check not passed"

}

function main() {
    case "$1" in
        "init" | "")
            shift
            sanity_checks
            install_pkgs
            xray_new_config --qrencode
            xray_run
            ;;
        "config")
            shift
            xray_new_config "$@"
            xray_run
            ;;
        "update")
            shift
            install_pkgs "$@"
            ;;
        "--help" | "-h")
            usage_msg
            ;;
        *)
            usage_msg
            ;;
    esac
}

main "$@"
