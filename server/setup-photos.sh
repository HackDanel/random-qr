#!/bin/sh
# One-time setup of the photo host (Apache + Let's Encrypt).
# Run on the server from this directory: sudo sh setup-photos.sh photos.example.com
# Tip: without a domain use sslip.io, e.g. photos.<public-ip>.sslip.io
#
# Existing sites are not touched: certbot runs in "certonly --webroot" mode,
# so it never edits Apache config and only issues a new, separate certificate.
# Every Apache reload is preceded by configtest; on failure the new sites are
# disabled again and Apache keeps running with the old config.
set -eu

NAME=${1:?usage: sudo sh setup-photos.sh <domain>}
OWNER=${SUDO_USER:?run via sudo from your user}
HERE=$(cd "$(dirname "$0")" && pwd)
CERTBOT=$(command -v certbot || echo /snap/bin/certbot)

safe_reload() {
    if ! apache2ctl configtest; then
        echo "configtest failed, rolling back" >&2
        a2dissite -q zz-photos zz-photos-ssl 2>/dev/null || true
        exit 1
    fi
    systemctl reload apache2
}

install -d -o "$OWNER" -g www-data -m 755 /var/www/photos /var/www/photos/p

# 1. HTTP vhost so Let's Encrypt can reach /.well-known/acme-challenge/
sed "s/__DOMAIN__/$NAME/g" "$HERE/zz-photos.conf" > /etc/apache2/sites-available/zz-photos.conf
a2ensite -q zz-photos
safe_reload

# 2. Separate certificate just for this name
"$CERTBOT" certonly --webroot -w /var/www/photos -d "$NAME" --cert-name "$NAME" \
    --non-interactive --keep-until-expiring \
    --deploy-hook "systemctl reload apache2"

# 3. HTTPS vhost
sed "s/__DOMAIN__/$NAME/g" "$HERE/zz-photos-ssl.conf" > /etc/apache2/sites-available/zz-photos-ssl.conf
a2ensite -q zz-photos-ssl
safe_reload

"$CERTBOT" renew --cert-name "$NAME" --dry-run
echo "OK: https://$NAME/p/"
