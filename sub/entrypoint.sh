#!/bin/bash
set -e

trap 'echo -e "\n❌ Ошибка в строке $LINENO. Код выхода: $?"; exit 1' ERR

IFACE=$(awk -F'= *' '/^iface *=/ {print $2}' /proxy.ini | tr -d '\r')
SSID=$(awk -F'= *' '/^ssid *=/ {print $2}' /proxy.ini | tr -d '\r')
PASSPHRASE=$(awk -F'= *' '/^passphrase *=/ {print $2}' /proxy.ini | tr -d '\r')

# ✅ Один раз установить шлюз
if [ ! -f /etc/gateway-setup.done ] && ip link show "$IFACE" &>/dev/null; then
  echo "⚙️ Running install-gateway.sh..."
  /usr/local/bin/install-gateway.sh --iface "$IFACE" --ssid "$SSID" --passphrase "$PASSPHRASE"
  touch /etc/gateway-setup.done
else
  echo "✅ Gateway already configured or interface missing. Skipping."
fi

echo "🚀 Starting processes..."
sing-box run --config /etc/sing-box/config.json &

dnsmasq --no-daemon &
hostapd -d /etc/hostapd/hostapd.conf &

# Блокируем контейнер
tail -f /dev/null
