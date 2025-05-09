# 📦 Xray Wi-Fi Gateway Setup

Автоматическая установка и настройка локального Wi-Fi-прокси с туннелированием трафика через Xray (sing-box).

Скрипт:
- устанавливает **sing-box** и генерирует конфиг по ссылке `vmess://`, `vless://` или `trojan://`
- разворачивает точку доступа (**hostapd**) и DHCP (**dnsmasq**)
- прокидывает весь трафик через **tun0**-интерфейс
- сохраняет **iptables**, настраивает **DNS**, запускает **systemd-сервисы**
- ⚡ работает с любой архитектурой: `amd64`, `arm64` (например, Orange Pi, Raspberry Pi)

---

## 🚀 Быстрый старт

### 1. Клонируй репозиторий на устройство с Linux (Ubuntu 22/24+)

```bash
git clone https://github.com/your-user/xray-wifi-proxy.git
cd xray-wifi-proxy
```

### 2. Запусти установку

```bash
bash setup.sh
```

### 3. Ответь на вопросы:

- 🔗 Вставь Xray ссылку (например: `vless://uuid@ip:port?...`)
- 📡 Выбери Wi-Fi интерфейс (например `wlan0`)
- 📶 Введи имя Wi-Fi сети (SSID), по умолчанию `TunnelNet`
- 🔐 Введи пароль Wi-Fi, минимум 8 символов (по умолчанию `tunnelproxy`)

---

## ✅ Что делает `setup.sh`

- Скачивает и устанавливает `sing-box` версии **1.11.8**
- Генерирует конфиг `/etc/sing-box/config.json` с маршрутизацией трафика
- Устанавливает `dnsmasq`, `hostapd`, `iptables`, включает **IP форвардинг**
- Генерирует конфиги Wi-Fi и DHCP по выбранному интерфейсу и имени сети
- Создаёт `systemd`-сервис `init-tunnel.service` для настройки при загрузке
- Прописывает `nameserver 1.1.1.1` и защищает `/etc/resolv.conf`
- Запускает всё через `systemctl enable ...` и стартует

---

## 🛠 Требования

- Ubuntu 22.04 или 24.04 (без GUI)
- Поддержка **tun** (`/dev/net/tun`, `net.ipv4.ip_forward = 1`)
- Wi-Fi адаптер с режимом **точки доступа (AP mode)**
- Интернет-доступ на устройстве

---

## 🔧 Дополнительно

- Все конфиги (`sing-box`, `dnsmasq`, `hostapd`) генерируются **динамически**
- При перезагрузке всё поднимается **автоматически**
- Для смены настроек: удали `systemd`-сервисы и запусти `setup.sh` заново

---

## 📁 Структура файлов

```text
setup.sh                 # Главный скрипт: спрашивает URL, интерфейс, SSID
setup-sing-box.sh        # Устанавливает sing-box и создаёт config.json
install-gateway.sh       # Настраивает Wi-Fi, DHCP, iptables, systemd
init-tunnel.sh           # Назначает IP интерфейсу, рестартует dnsmasq
prepare-wifi.sh          # Отключает NetworkManager, rfkill, wpa_supplicant
```

---

## 🐳 Docker (альтернативно)

Поддерживается автоматическая сборка через `Dockerfile` с конфигом из `proxy.ini`:

```ini
url = vless://uuid@ip:port?...    # Xray URL
iface = wlan0                     # Wi-Fi интерфейс
ssid = TunnelNet                  # Имя сети
passphrase = tunnelproxy          # Пароль
```

```bash
docker build -t singbox-gateway .
docker run --privileged --cap-add=NET_ADMIN --device /dev/net/tun -it singbox-gateway
```

> ❗ В Docker Wi-Fi обычно недоступен — использовать только для теста туннеля.

---

## 📞 Поддержка

- Если `setup.sh` ничего не делает — проверь, нет ли `exit` внутри `setup-sing-box.sh`
- Если Wi-Fi не поднимается — проверь, что адаптер поддерживает **AP Mode** (`iw list`)
- Если не работает DNS — проверь `/etc/resolv.conf`, отключи `systemd-resolved`
- Если туннель не стартует — проверь `systemctl status sing-box`

---

✅ Готово! Устройство теперь раздаёт Wi-Fi с туннелем через Xray.

Поддерживаются любые устройства с ARM или x86 архитектурой.
