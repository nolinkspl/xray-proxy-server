#!/bin/bash

WIFI_IFACE="$1"

# Assign static IP to Wi-Fi interface
ip addr add 192.168.69.1/24 dev "$WIFI_IFACE"

# Restart DHCP/DNS service
systemctl restart dnsmasq
