#!/usr/bin/env bash
set -e

DOMAIN="ketrn.com"
UPSTREAM="ketrn_frontend:3000"
EMAIL="1987lex@gmail.com"

BASE_DIR="/home/docker/nginx"
CONF_DIR="$BASE_DIR/nginx/conf.d"

HTTP_TPL="$CONF_DIR/${DOMAIN}.http.conf.tpl"
HTTPS_TPL="$CONF_DIR/${DOMAIN}.https.conf.tpl"
ACTIVE_CONF="$CONF_DIR/${DOMAIN}.conf"

echo "==> [1/6] Generating HTTP-only nginx config"

sed \
  -e "s/{{DOMAIN}}/$DOMAIN/g" \
  "$HTTP_TPL" > "$ACTIVE_CONF"

docker compose -f "$BASE_DIR/docker-compose.yml" restart nginx

echo "==> [2/6] Waiting for HTTP to become available"
sleep 3

echo "==> [3/6] Checking HTTP availability"
if ! curl -fs "http://$DOMAIN" >/dev/null; then
  echo "ERROR: http://$DOMAIN is not reachable"
  exit 1
fi

echo "==> [4/6] Requesting Let's Encrypt certificate"

docker exec certbot certbot certonly \
  --webroot \
  -w /var/www/certbot \
  -d "$DOMAIN" \
  -d "www.$DOMAIN" \
  --email "$EMAIL" \
  --agree-tos \
  --no-eff-email \
  --non-interactive

echo "==> [5/6] Switching nginx config to HTTPS"

sed \
  -e "s/{{DOMAIN}}/$DOMAIN/g" \
  -e "s/{{UPSTREAM}}/$UPSTREAM/g" \
  "$HTTPS_TPL" > "$ACTIVE_CONF"

echo "==> [6/6] Restarting nginx with HTTPS"
docker compose -f "$BASE_DIR/docker-compose.yml" restart nginx

echo "======================================"
echo " HTTPS for $DOMAIN is READY"
echo " Certbot auto-renew is ACTIVE"
echo "======================================"
