# Xray Reality Script

This is a convenient script to generate new configs and run the latest [REALITY protocol](https://github.com/XTLS/REALITY) on a server, 
which uses TLS certificates from a camouflag website (some example of which are in `camouflag.txt`). 

### Usage

The general idea is to grab a template `config.json` file, for example see [Reality config templates](https://github.com/chika0801/Xray-examples), 
and modify for our own use cases. Also the templates in `configs` directory can be used. What script does, is to generate the UUID for the server, 
with `xray uuid` or `cat /proc/sys/kernel/random/uuid`, then create the X25519 private, public key pair, with `xray x25519` and use a short id generated 
with `openssl rand -hex 4`, and populate the template configurations. The `xray-core` must be `v1.8.0` or higher.

```
Usage: ./reality.sh {init (Default) | config [--url (Default) | --qrencode] | update | --help | -h}

init:   Default, install, update required packages, generate a config, and start xray
config [--url | --qrencode]: generate a new config based on a template config
        --url: print to terminal the VLESS url
        --qrencode: print the url and also the QR encoded version to terminal
update: update the required packages, including xray-core
--help | -h: print this help message
```

Note that the script will copy the newly generated `config.json` into the default xray configuration path, `/usr/local/etc/xray/`, 
if there is one alreay, it will back it up. You can use the default `xray.service` to start and sttop the service, 
e.g. `systemctl stop xray`.
