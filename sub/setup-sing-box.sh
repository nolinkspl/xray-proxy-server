#!/bin/bash
set -e

trap 'echo -e "\n❌ Ошибка в строке $LINENO. Код выхода: $?"; exit 1' ERR

# — URL-парсинг —
if [[ $1 == "--url" && -n $2 ]]; then
  XRAY_URL="$2"
else
  read -rp $'\n🌐 Вставьте ссылку Xray (vmess://, vless://, trojan://): ' XRAY_URL
fi

# Download and install sing-box binary if not present
if ! command -v sing-box >/dev/null; then
  echo "🔧 Installing sing-box..."
  ARCH=$(uname -m)
  case $ARCH in
    x86_64) ARCH=amd64;;
    aarch64) ARCH=arm64;;
    *) echo "Unsupported architecture: $ARCH"; exit 1;;
  esac

  VERSION="1.11.8"
  SING_BOX_URL="https://github.com/SagerNet/sing-box/releases/download/v$VERSION/sing-box-$VERSION-linux-$ARCH.tar.gz"

  echo "Trying to download $SING_BOX_URL"

  curl -L -o sing-box.tar.gz "$SING_BOX_URL"
  tar -xf sing-box.tar.gz
  sudo install -m 755 sing-box-*/sing-box /usr/local/bin/sing-box
  rm -rf sing-box.tar.gz sing-box-*
  echo "✅ sing-box v$VERSION installed to /usr/local/bin/sing-box"
fi

PROTO=""
SERVER=""
PORT=""
UUID=""
TLS_ENABLED="false"
PASSWORD=""

echo "Xray url = $XRAY_URL"

set -x

if [[ $XRAY_URL == vmess://* ]]; then
  CONFIG_JSON=$(echo "${XRAY_URL#vmess://}" | base64 -d 2>/dev/null)
  [[ -z $CONFIG_JSON ]] && { echo "❌ Failed to decode vmess link."; exit 1; }
  PROTO="vmess"
  SERVER=$(echo "$CONFIG_JSON" | jq -r .add)
  PORT=$(echo "$CONFIG_JSON" | jq -r .port)
  UUID=$(echo "$CONFIG_JSON" | jq -r .id)
  TLS_RAW=$(echo "$CONFIG_JSON" | jq -r .tls)
  TLS_ENABLED=$( [[ "$TLS_RAW" == "tls" || "$TLS_RAW" == "true" ]] && echo true || echo false )
  ALTERID=$(echo "$CONFIG_JSON" | jq -r '.aid // empty')

elif [[ $XRAY_URL == vless://* ]]; then
  PROTO="vless"
  FULL=${XRAY_URL#vless://}
  UUID=${FULL%@*}
  REST=${FULL#*@}
  SERVER=${REST%%:*}
  PORT=${REST#*:}; PORT=${PORT%%\?*}
  SECURITY=$(echo "$REST" | grep -oP 'security=\K[^&]*' || echo "")
  TLS_ENABLED=$( [[ "$SECURITY" == "tls" || "$SECURITY" == "reality" ]] && echo true || echo false )

elif [[ $XRAY_URL == trojan://* ]]; then
  PROTO="trojan"
  FULL=${XRAY_URL#trojan://}
  PASSWORD=${FULL%%@*}
  REST=${FULL#*@}
  SERVER=${REST%%:*}
  PORT=${REST#*:}; PORT=${PORT%%\?*}
  TLS_ENABLED=true

else
  echo "❌ Only vmess://, vless:// and trojan:// links are supported."
  exit 1
fi

echo "Configs exctraction done! SERVER=$SERVER, PORT=$PORT, UUID=$UUID, PASSWORD=$PASSWORD"

[[ -z $SERVER || -z $PORT || (-z $UUID && -z $PASSWORD) ]] && { echo "❌ Failed to extract connection parameters."; exit 1; }

mkdir -p /etc/sing-box
cat <<EOF | sudo tee /etc/sing-box/config.json > /dev/null
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "remote",
        "address": "https://1.1.1.1/dns-query",
        "detour": "proxy"
      },
      {
        "tag": "local",
        "address": "local"
      }
    ],
    "rules": [
      {
        "domain_suffix": ["ru", "binance.com", "bybit.com"],
        "server": "local"
      }
    ],
    "strategy": "prefer_ipv4"
  },
  "inbounds": [
    {
      "type": "tun",
      "interface_name": "tun0",
      "address": [
        "172.19.0.1/30"
      ],
      "mtu": 9000,
      "auto_route": true,
      "strict_route": true,
      "stack": "system",
      "sniff": true,
      "sniff_override_destination": true
    }
  ],
  "outbounds": [
    {
      "type": "$PROTO",
      "tag": "proxy",
      "server": "$SERVER",
      "server_port": $PORT,
$( [[ $PROTO == "trojan" ]] && echo "      \"password\": \"$PASSWORD\",")
$( [[ $PROTO == "vmess" || $PROTO == "vless" ]] && echo "      \"uuid\": \"$UUID\",")
$( [[ $PROTO == "vmess" ]] && echo "      \"alter_id\": $ALTERID,")
      "tls": {
        "enabled": $TLS_ENABLED
      }
    },
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
  "route": {
    "geoip": {
      "download_url": "https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db",
      "path": "geoip.db"
    },
    "rule_set": [
      {
        "tag": "geoip-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs",
        "download_detour": "proxy"
      },
      {
        "tag": "geoip-us",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-us.srs",
        "download_detour": "proxy"
      }
    ],
    "rules": [
      {
        "domain_suffix": ["ru", "binance.com", "bybit.com"],
        "outbound": "direct"
      },
      {
        "ip_cidr": ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"],
        "outbound": "direct"
      },
      {
        "rule_set": "geoip-cn",
        "outbound": "direct"
      },
      {
        "outbound": "proxy"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "rule_set": "geoip-us",
        "rule_set_ip_cidr_match_source": true,
        "action": "reject"
      }
    ],
    "auto_detect_interface": true
  },
  "experimental": {
    "cache_file": {
      "enabled": true
    }
  }
}
EOF

echo -e "\n✅ sing-box config saved to /etc/sing-box/config.json"
echo "   Protocol: $PROTO"
echo "   Server: $SERVER:$PORT"
[[ -n $UUID ]] && echo "   UUID: $UUID"
[[ -n $PASSWORD ]] && echo "   Password: [hidden]"

set +x