#!/bin/sh
# Host setup for a Raspberry Pi running this stack. Idempotent; run as root
# from the repo checkout:  sudo sh host/setup.sh
# Some changes (config.txt) take effect after a reboot.
set -e

cd "$(dirname "$0")"

echo "== journald: volatile (RAM-only) journal"
mkdir -p /etc/systemd/journald.conf.d
install -m 644 journald.conf.d/10-volatile.conf /etc/systemd/journald.conf.d/
systemctl restart systemd-journald
rm -rf /var/log/journal

# Blocky reaches unbound via the host IP on 5354 (from the docker bridge and
# from the other DNS server), which UFW otherwise drops.
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
    echo "== ufw: allow unbound (5354) from LAN and docker networks"
    for src in 192.168.0.0/16 172.16.0.0/12; do
        ufw allow from "$src" to any port 5354 comment "unbound" >/dev/null
    done
fi

echo "== bluetooth/wifi: disable (eth0 only)"
systemctl disable --now bluetooth.service hciuart.service 2>/dev/null || true
nmcli radio wifi off 2>/dev/null || true

CONFIG=/boot/firmware/config.txt
if [ -f "$CONFIG" ]; then
    echo "== $CONFIG: disable unused hardware (after reboot)"
    [ -f "$CONFIG.orig" ] || cp "$CONFIG" "$CONFIG.orig"
    sed -i \
        -e 's/^dtparam=audio=on/dtparam=audio=off/' \
        -e 's/^camera_auto_detect=1/camera_auto_detect=0/' \
        -e 's/^display_auto_detect=1/display_auto_detect=0/' \
        "$CONFIG"
    for overlay in disable-wifi disable-bt; do
        grep -q "^dtoverlay=$overlay" "$CONFIG" || printf '[all]\ndtoverlay=%s\n' "$overlay" >> "$CONFIG"
    done
fi

# live-restore keeps containers (and DNS) running while dockerd restarts or
# upgrades; journald is the default driver for anything outside compose.
DAEMON_JSON=/etc/docker/daemon.json
if [ ! -f "$DAEMON_JSON" ]; then
    echo "== docker: live-restore + journald logging (restarts docker)"
    cat > "$DAEMON_JSON" <<'EOF'
{
  "live-restore": true,
  "log-driver": "journald"
}
EOF
    systemctl restart docker
elif ! grep -q '"live-restore"' "$DAEMON_JSON"; then
    echo "!! $DAEMON_JSON exists; add \"live-restore\": true and \"log-driver\": \"journald\" by hand"
fi

echo "done. reboot to apply $CONFIG changes."
