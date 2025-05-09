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
  /usr/local/bin/setup-sing-box.sh --url "$URL" || { echo "❌ setup-sing-box.sh failed with code $?"; exit 1; }'

COPY sub/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]