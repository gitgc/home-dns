#!/bin/sh
set -e

apk add --no-cache docker-cli > /dev/null 2>&1

DOMAIN="${DOH_SUBDOMAIN}.${CADDY_DOMAIN}"
CERT_SRC="/caddy-certs/${DOMAIN}/${DOMAIN}.crt"
KEY_SRC="/caddy-certs/${DOMAIN}/${DOMAIN}.key"

sync_certs() {
    if [ -f "$CERT_SRC" ]; then
        install -m 644 "$CERT_SRC" /blocky-certs/server.crt
        install -m 644 "$KEY_SRC"  /blocky-certs/server.key
        echo "synced certs for ${DOMAIN}"
    else
        echo "cert not yet available at ${CERT_SRC}"
        return 1
    fi
}

sync_certs

while true; do
    sleep 3600
    if [ -f "$CERT_SRC" ] && [ "$CERT_SRC" -nt /blocky-certs/server.crt ]; then
        sync_certs
        docker restart dns-blocky || true
        echo "restarted blocky after cert renewal"
    fi
done
