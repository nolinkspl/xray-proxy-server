#!/bin/bash
set -e

# ==========================
# 🛠 Parse arguments
# ==========================

while [[ $# -gt 0 ]]; do
  case $1 in
    --iface)
      WIFI_IFACE="$2"
      shift 2
      ;;
    --ssid)
      SSID="$2"
      shift 2
      ;;
    --passphrase)
      PASSPHRASE="$2"
      shift 2
      ;;
    *)
      echo "❌ Unknown argument: $1"
      exit 1
      ;;
  esac
done

# ==========================
# 🔍 Validate required arguments
# ==========================

if [[ -z "$WIFI_IFACE" || -z "$SSID" || -z "$PASSPHRASE" ]]; then
  echo "❌ Missing required arguments."
  echo "Usage: $0 --iface wlan0 --ssid TunnelNet --passphrase yourpass"
  exit 1
fi

./sub/prepare-wifi.sh "$WIFI_IFACE"

# ==========================
# 📦 Install dependencies
# ==========================

echo "🔧 Installing required packages..."
apt update
apt install -y hostapd dnsmasq iptables iproute2 net-tools iptables-persistent

# ==========================
# 🧩 Copy configuration files
# ==========================

echo "📂 Copying configuration files..."
mkdir -p /etc/dnsmasq.d /etc/hostapd

# Generate dnsmasq config
cat <<EOF > /etc/dnsmasq.d/tunnel.conf
interface=$WIFI_IFACE
bind-interfaces
dhcp-range=192.168.69.10,192.168.69.100,12h
dhcp-option=3,192.168.69.1
dhcp-option=6,1.1.1.1
server=1.1.1.1
log-queries
log-dhcp
EOF

# Generate hostapd config with selected SSID and passphrase
cat <<EOF > /etc/hostapd/hostapd.conf
interface=$WIFI_IFACE
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
ieee80211n=1
wmm_enabled=1
ht_capab=[HT40][SHORT-GI-20][SHORT-GI-40]
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$PASSPHRASE
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

sed -i "s|#DAEMON_CONF=.*|DAEMON_CONF=\"/etc/hostapd/hostapd.conf\"|" /etc/default/hostapd

# ==========================
# 🌐 Configure Wi-Fi interface
# ==========================

echo "🌐 Configuring Wi-Fi interface..."
if ! ip link show "$WIFI_IFACE" &>/dev/null; then
  echo "⚠️ Interface $WIFI_IFACE hasn't found. I'll create dummy..."
  ip link add name "$WIFI_IFACE" type dummy
fi
ip addr flush dev "$WIFI_IFACE" || true
ip addr add 192.168.69.1/24 dev "$WIFI_IFACE"

# ==========================
# 🔁 Enable IP forwarding
# ==========================

echo "🔁 Enabling IP forwarding..."
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-tunnel.conf
sysctl -p /etc/sysctl.d/99-tunnel.conf

# ==========================
# 🔥 Configure iptables
# ==========================

echo "🔥 Configuring iptables..."
iptables -F
iptables -t nat -F
iptables -P FORWARD ACCEPT
iptables -t nat -A POSTROUTING -s 192.168.69.0/24 -o tun0 -j MASQUERADE
iptables -A FORWARD -i "$WIFI_IFACE" -o tun0 -j ACCEPT
iptables -A FORWARD -i tun0 -o "$WIFI_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "💾 Saving iptables rules..."
netfilter-persistent save

# ==========================
# 📡 Enable services on boot
# ==========================

echo "📡 Enabling services..."
systemctl unmask hostapd || true
systemctl enable hostapd
systemctl enable dnsmasq

# ==========================
# 🚫 Disable systemd-resolved
# ==========================

echo "🚫 Disabling systemd-resolved if active..."
systemctl disable --now systemd-resolved 2>/dev/null || true
rm -f /etc/resolv.conf

# ==========================
# 📝 Set static DNS
# ==========================

echo "📝 Writing static DNS config..."
echo "nameserver 1.1.1.1" > /etc/resolv.conf
chattr +i /etc/resolv.conf || echo "⚠️ Failed to lock /etc/resolv.conf (optional)."

# ==========================
# ⚙️ Install init-tunnel.service
# ==========================

echo "⚙️ Installing init-tunnel systemd service..."
cp ./sub/init-tunnel.sh /usr/local/bin/init-tunnel.sh
chmod +x /usr/local/bin/init-tunnel.sh

cat <<EOF > /etc/systemd/system/init-tunnel.service
[Unit]
Description=Init tunnel Wi-Fi interface and restart dnsmasq
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/init-tunnel.sh $WIFI_IFACE
Type=oneshot
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload

systemctl enable init-tunnel.service
systemctl enable sing-box

# ==========================
# ✅ Done
# ==========================

echo "✅ Gateway installation complete."
echo "   To start manually:"
echo "   systemctl start hostapd"
echo "   systemctl start dnsmasq"
echo "   systemctl start init-tunnel.service"
