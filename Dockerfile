FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# ========== 📦 Install dependencies ==========
RUN apt update && apt install -y \
    systemd systemd-sysv \
    curl jq iproute2 iptables \
    dnsmasq hostapd net-tools \
    iptables-persistent sudo vim

# ========== ⚙️ Systemd compatibility ==========
VOLUME ["/sys/fs/cgroup"]
STOPSIGNAL SIGRTMIN+3

# ========== 📂 Copy all scripts and config ==========
COPY proxy.ini /proxy.ini
COPY sub/setup-sing-box.sh sub/install-gateway.sh sub/init-tunnel.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# ========== 🚀 Parse config and run setup ==========
RUN bash -x -e -c '\
  URL=$(grep "^url" /proxy.ini | cut -d"=" -f2- | xargs); \
  echo "⚙️ Using URL: $URL"; \
  /usr/local/bin/setup-sing-box.sh --url "$URL"'

RUN set -e && \
    IFACE=$(awk -F'= *' '/^iface *=/ {print $2}' /proxy.ini | tr -d '\r') && \
    SSID=$(awk -F'= *' '/^ssid *=/ {print $2}' /proxy.ini | tr -d '\r') && \
    PASSPHRASE=$(awk -F'= *' '/^passphrase *=/ {print $2}' /proxy.ini | tr -d '\r') && \
    /usr/local/bin/install-gateway.sh --iface "$IFACE" --ssid "$SSID" --passphrase "$PASSPHRASE"

# ========== 🔌 Enable services ==========
RUN systemctl enable sing-box.service \
    && systemctl enable dnsmasq \
    && systemctl enable hostapd \
    && systemctl enable init-tunnel.service

# ========== 📜 Show logs on startup ==========
CMD bash -c '\
  systemctl start init-tunnel.service && \
  journalctl -fu sing-box -n 30 & \
  journalctl -fu dnsmasq -n 20 & \
  journalctl -fu hostapd -n 20 & \
  exec /lib/systemd/systemd'
