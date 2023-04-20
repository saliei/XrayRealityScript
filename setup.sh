#!/usr/bin/env bash
# 
# A utility script to setup Xray REALITY (Vless-XTLS-uTLS-REALITY)
#

# TODO: currently Debian based, support other distros
# TODO: optionally use X-UI platform also
# TODO: add optionally the nginx version
# TODO: telegram-bot optional
# TODO: option for new inbound configs

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

CURDIR="$(dirname $0)"
GITREP="https://github.com/saliei/XrayRealityScript"
LOGGER="XRAY-REALITY-SCRIPT"
TEMPL_CONFIG="$CURDIR/configs/config.json"

trap "DIE" SIGINT
trap "DIE" SIGQUIT
trap "DIE" SIGQUIT

function LOG() {
    CURDATE="${BLUE}$(date +'%Y-%m-%d %T')${RESET}"

    case $1 in
        "DEBUG")
            shift
            LOGLEVEL="${GREEN}   DEBUG${RESET}"
            ;;
        "INFO")
            shift
            LOGLEVEL="${CYAN}    INFO${RESET}"
            ;;
        "WARNING")
            shift
            LOGLEVEL="${YELLOW} WARNING${RESET}"
            ;;
        "ERROR")
            shift
            LOGLEVEL="${RED}   ERROR${RESET}"
            ;;
        "CRITICAL")
            shift
            LOGLEVEL="${BRED}CRITICAL${RESET}"
            ;;
        *)
            LOGLEVEL="${WHITE} NOLEVEL${RESET}"
            ;;
    esac

    LOGMSG="$1"
    echo -e "$CURDATE $LOGGER $LOGLEVEL: $LOGMSG"
}

function DIE() {
    LOG CRITICAL "the die function"
    exit 1
}

function usage_msg() {
    echo "usage"
}

function is_root() {
    [ "$EUID" -eq 0 ] || (LOG ERROR "must be root to use the script!" && DIE)
}

function sysctl_confs() {
    # TODO: optional sysctl confs
    echo "sysctl confs"
}

function install_pkgs() {
    is_root

    LOG INFO "updating & upgrading system"
    #apt update -y && apt upgrade -y

    pkgs=("openssl" "qrencode" "jq" "curl")

    for pkg in ${pkgs[@]}; do
        LOG INFO "installing package: $pkg"
        echo $pkg
        #apt install -y pkg
    done

    LOG INFO "installing xray pre-release version with xray-install script as the root user"
    #bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --beta -u root

}

function xray_config() {
    #xuuid=$(xray uuid)
    uuid="theuuid"
    #xkeys=$(xray x25519)
    #xpublic_key=$(echo $xkeys | cut -d " " -f 4)
    public_key="xpublickey"
    #xprivate_key=$(echo $xkeys  | cut -d " " -f 6)
    private_key="xprivatekey"
    #shortid=$(openssl rand -hex 4)
    short_id="theshortid"

    CONFIG="$CURDIR/config.json"
    cp "$TEMPL_CONFIG" "$CONFIG"

    cat <<< $(jq --arg public_key  $public_key  '.inbounds[1].streamSettings.realitySettings.publicKey  = $public_key'  "$CONFIG") > "$CONFIG"
    cat <<< $(jq --arg private_key $private_key '.inbounds[1].streamSettings.realitySettings.privateKey = $private_key' "$CONFIG") > "$CONFIG"
    cat <<< $(jq --arg short_id    $short_id    '.inbounds[1].streamSettings.realitySettings.shortIds   = [$short_id]'  "$CONFIG") > "$CONFIG"

}

function main() {
    #install_pkgs
    xray_config
}

main "@"
