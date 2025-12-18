
#!/usr/bin/env bash
set -e

DOMAINS_FILE="./domains.txt"
BASE_DIR="/home/docker/nginx"
CONF_DIR="$BASE_DIR/nginx/conf.d"
EMAIL="1987lex@gmail.com"

DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "==> DRY-RUN MODE ENABLED"
fi

SERVER_IP=$(curl -s https://api.ipify.org)

http_tpl="$CONF_DIR/domain.http.conf.tpl"
https_tpl="$CONF_DIR/domain.https.conf.tpl"

while IFS=";" read -r DOMAIN UPSTREAM; do
  [[ -z "$DOMAIN" ]] && continue

  echo "======================================"
  echo "DOMAIN: $DOMAIN"
  echo "UPSTREAM: $UPSTREAM"
  echo "======================================"

  # DNS check
  DNS_IP=$(dig +short "$DOMAIN" | head -n1)
  if [[ "$DNS_IP" != "$SERVER_IP" ]]; then
    echo "❌ DNS mismatch: $DOMAIN → $DNS_IP (expected $SERVER_IP)"
    continue
  fi

  echo "✅ DNS OK"

  CONF_FILE="$CONF_DIR/$DOMAIN.conf"

  echo "==> Generating HTTP config"
  sed "s/{{DOMAIN}}/$DOMAIN/g" "$http_tpl" > "$CONF_FILE"

  docker compose restart nginx
  sleep 3

  if ! curl -fs "http://$DOMAIN" >/dev/null; then
    echo "❌ HTTP check failed for $DOMAIN"
    continue
  fi

  echo "✅ HTTP reachable"

  CERTBOT_ARGS=(
    certbot certonly
    --webroot -w /var/www/certbot
    -d "$DOMAIN"
    --email "$EMAIL"
    --agree-tos
    --no-eff-email
    --non-interactive
  )

  $DRY_RUN && CERTBOT_ARGS+=(--dry-run)

  echo "==> Requesting certificate"
  docker exec certbot "${CERTBOT_ARGS[@]}"

  $DRY_RUN && echo "==> DRY-RUN finished, skipping HTTPS switch" && continue

  echo "==> Switching to HTTPS config"
  sed \
    -e "s/{{DOMAIN}}/$DOMAIN/g" \
    -e "s|{{UPSTREAM}}|$UPSTREAM|g" \
    "$https_tpl" > "$CONF_FILE"

  docker compose restart nginx

  echo "✅ HTTPS enabled for $DOMAIN"

done < "$DOMAINS_FILE"

echo "======================================"
echo "DONE"
