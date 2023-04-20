#!/usr/bin/env bash
# 
# A utility script to setup Xray REALITY (Vless-XTLS-uTLS-REALITY)
#

# TODO: currently Debian based, support other distros
# TODO: optionally use X-UI platform also
# TODO: option for new inbound configs
# TODO: add xray-core with an update option
# TODO: adding multiple configs for adblocking and filtering basic geoips
# TODO: option to do kernel opts

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
CONFIG="$CURDIR/config.json"
XRAY_ORIG_CONFIG="/usr/local/etc/xray/config.json"

CMFGS="$CURDIR/camouflags.txt"
TCP_PORT="443"

trap "DIE" SIGINT
trap "DIE" SIGQUIT
trap "DIE" SIGQUIT

function LOG() {
    CURDATE="${BLUE}$(date +'%Y-%m-%d %T')${RESET}"

    case $1 in
        "DEBUG")
            shift
            LOGLEVEL="${GREEN}DEBUG${RESET}"
            ;;
        "INFO")
            shift
            LOGLEVEL="${CYAN} INFO${RESET}"
            ;;
        "WARNING")
            shift
            LOGLEVEL="${YELLOW} WARN${RESET}"
            ;;
        "ERROR")
            shift
            LOGLEVEL="${RED}ERROR${RESET}"
            ;;
        "CRITICAL")
            shift
            LOGLEVEL="${BRED}CRITC${RESET}"
            ;;
        *)
            LOGLEVEL="${WHITE}NOLEVEL${RESET}"
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

    pkgs=("openssl" "qrencode" "jq" "curl" "xclip")

    for pkg in ${pkgs[@]}; do
        LOG INFO "installing package: $pkg"
        echo $pkg
        #apt install -y pkg
    done

    LOG INFO "installing xray pre-release version with xray-install script as the root user"
    #bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --beta -u root

}

function get_public_ip() {
    public_ip=$(curl -s ifconfig.me)
    echo $public_ip
}

function xray_config() {
    declare -n confvars="$1"
    #xuuid=$(xray uuid)
    uuid="theuuid"
    confvars["uuid"]=$uuid
    LOG INFO "generate UUID: $uuid"

    #xkeys=$(xray x25519)
    #xpublic_key=$(echo $xkeys | cut -d " " -f 4)
    public_key="xpublickey"
    confvars["public_key"]=$public_key
    LOG INFO "generated public key: $public_key"

    #xprivate_key=$(echo $xkeys  | cut -d " " -f 6)
    private_key="xprivatekey"
    confvars["private_key"]=$private_key
    LOG INFO "generated private key: $private_key"

    #shortid=$(openssl rand -hex 4)
    short_id="theshortid"
    confvars["short_id"]=$short_id

    inbound_listen_port="49649"
    confvars["inbound_listen_port"]=$inbound_listen_port

    flow="xtls-rprx-vision"
    confvars["flow"]=$flow

    email="testemail"
    confvars["email"]=$email

    public_ip=$(get_public_ip)
    confvars["public_ip"]=$public_ip

    LOG WARNING "using $TEMPL_CONFIG as the template config file"
    cp "$TEMPL_CONFIG" "$CONFIG"
    #
    # TODO: should be optional, based on user flags
    LOG INFO "reading the first camouflag website"
    readarray -t cmfgsites < "$CMFGS"
    cmfgsite="${cmfgsites[0]}"
    confvars["cmfgsite"]=$cmfgsite
    LOG WARNING "using $cmfgsite as the camouflag website"
    cmfgsite_port="${cmfgsite}:${TCP_PORT}"
    cmfgsite_www="www.${cmfgsite}"

    LOG INFO "populating config.json file"
    cat <<< $(jq --arg uuid  $uuid '.inbounds[1].settings.clients[0].id = $uuid' "$CONFIG") > "$CONFIG"
    cat <<< $(jq --arg flow  $flow '.inbounds[1].settings.clients[0].flow = $flow' "$CONFIG") > "$CONFIG"
    cat <<< $(jq --arg email  $flow '.inbounds[1].settings.clients[0].email = $email' "$CONFIG") > "$CONFIG"

    cat <<< $(jq --arg public_key  $public_key \
        '.inbounds[1].streamSettings.realitySettings.publicKey  = $public_key'  "$CONFIG") > "$CONFIG"
    cat <<< $(jq --arg private_key $private_key \
        '.inbounds[1].streamSettings.realitySettings.privateKey = $private_key' "$CONFIG") > "$CONFIG"
    cat <<< $(jq --arg short_id    $short_id \
        '.inbounds[1].streamSettings.realitySettings.shortIds   = [$short_id]'  "$CONFIG") > "$CONFIG"

    cat <<< $(jq --arg cmfgsite_port $cmfgsite_port \
        '.inbounds[1].streamSettings.realitySettings.dest = $cmfgsite_port'  "$CONFIG") > "$CONFIG"
    cat <<< $(jq --arg cmfgsite $cmfgsite --arg cmfgsite_www $cmfgsite_www \
        '.inbounds[1].streamSettings.realitySettings.serverNames = [$cmfgsite, $cmfgsite_www]' "$CONFIG") > "$CONFIG"

    LOG INFO "backing up $XRAY_ORIG_CONFIG and replacing with new config"
    xray_orig_config_dir=$(dirname $XRAY_ORIG_CONFIG)
    [ -f "$xray_orig_config_dir/config.json.old" ] && LOG WARNING "$xray_orig_config_dir/config.json.old exists, replacing"
    #mv "$XRAY_ORIG_CONFIG" "$(dirname $XRAY_ORIG_CONFIG)/config.json.old"
    #cp $CONFIG "$(dirname $XRAY_ORIG_CONFIG)/"

}

function xray_start() {
    LOG DEBUG "enable and start xray.service"
    systemctl enable --now xray 

    LOG DEBUG "check status on xray service"
    systemctl status xray

    [ $? -ne 0 ] && (LOG CRITICAL "something went wrong when starting xray" && DIE)
}

function gen_url() {
    declare -A vars
    xray_config vars

    random_name=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8 ; echo '')

    LOG DEBUG "generated url"
    url="vless://${vars["uuid"]}@${vars["public_ip"]}:${vars["inbound_listen_port"]}?\
type=tcp&security=reality&sni=${vars["cmfgsite"]}&pbk=${vars["public_key"]}&\
flow=${vars["flow"]}&sid=${vars["short_id"]}&fp=chrome#${vars["email"]}-$random_name"
    echo $url

    if command -v xclip &>/dev/null; then
        LOG INFO "url copied to clipboard"
        echo $url | xclip -selection clipboard
    fi
    
    LOG INFO "generating QR encoding of the url"
    qrencode -s 120 -t ANSIUTF8 $url

}

function main() {
    #install_pkgs
    #xray_config
    gen_url
    #xray_start


}

main "@"
