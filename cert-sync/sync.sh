#!/bin/sh
set -e

DOMAIN="${DOH_SUBDOMAIN}.${CADDY_DOMAIN}"
CERT_SRC="/caddy-certs/${DOMAIN}/${DOMAIN}.crt"
KEY_SRC="/caddy-certs/${DOMAIN}/${DOMAIN}.key"

sync_certs() {
    install -m 644 "$CERT_SRC" /blocky-certs/server.crt
    install -m 640 "$KEY_SRC"  /blocky-certs/server.key
    echo "synced certs for ${DOMAIN}"
}

# Caddy may still be issuing the first cert; wait for it rather than exiting
until [ -f "$CERT_SRC" ] && [ -f "$KEY_SRC" ]; do
    echo "cert not yet available at ${CERT_SRC}, retrying in 30s"
    sleep 30
done

sync_certs

while true; do
    sleep 3600
    if [ -f "$CERT_SRC" ] && [ "$CERT_SRC" -nt /blocky-certs/server.crt ]; then
        sync_certs
        docker restart dns-blocky || true
        echo "restarted blocky after cert renewal"
    fi
done
