#!/bin/bash
set -e

echo "🌐 Sing-box + Wi-Fi Gateway setup"

read -rp "Paste your Xray link (vmess://, vless://, trojan://): " XRAY_URL

echo "🔍 Available network interfaces:"
interfaces=($(ip -o link show | awk -F': ' '{print $2}' | grep -v lo))
for i in "${!interfaces[@]}"; do echo " [$i] ${interfaces[$i]}"; done
read -rp "Select interface number: " index
WIFI_IFACE="${interfaces[$index]}"

read -rp "Enter Wi-Fi SSID (default: TunnelNet): " SSID
SSID=${SSID:-TunnelNet}

read -rsp "Enter Wi-Fi password (min 8 chars, default: tunnelproxy): " PASSPHRASE
echo
PASSPHRASE=${PASSPHRASE:-tunnelproxy}

# Pass everything to scripts
bash ./sub/setup-sing-box.sh --url "$XRAY_URL"
bash ./sub/install-gateway.sh --iface "$WIFI_IFACE" --ssid "$SSID" --passphrase "$PASSPHRASE"
