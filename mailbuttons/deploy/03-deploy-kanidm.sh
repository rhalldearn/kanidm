#!/usr/bin/env bash
#
# 03-deploy-kanidm.sh — Build mailbuttons-kanidm image and deploy to VPS
#
# Run from dev machine (repo root). Builds the Docker image locally,
# transfers it to the VPS, and starts the service stack.
#
# Usage: ./mailbuttons/deploy/03-deploy-kanidm.sh
#
set -euo pipefail

VPS_IP="79.99.45.220"
VPS_USER="root"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEPLOY_DIR="$(cd "$(dirname "$0")" && pwd)"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-richard@mailbuttons.com}"

echo "==> Building mailbuttons-kanidm Docker image..."
echo "    (This will take a while on first build)"
docker build -t mailbuttons-kanidm:latest -f "${REPO_ROOT}/server/Dockerfile" "${REPO_ROOT}"

echo ""
echo "==> Transferring image to VPS (this may take several minutes)..."
docker save mailbuttons-kanidm:latest | ssh "${VPS_USER}@${VPS_IP}" docker load

echo ""
echo "==> Uploading configuration files..."
scp "${DEPLOY_DIR}/docker-compose.yml" "${VPS_USER}@${VPS_IP}:/opt/kanidm/"
scp "${DEPLOY_DIR}/nginx.conf" "${VPS_USER}@${VPS_IP}:/opt/kanidm/"
scp "${DEPLOY_DIR}/server.toml" "${VPS_USER}@${VPS_IP}:/opt/kanidm/data/server.toml"

echo ""
echo "==> Generating self-signed TLS cert for Kanidm's internal listener..."
ssh "${VPS_USER}@${VPS_IP}" bash -s <<'REMOTE_SELFSIGN'
set -euo pipefail

if [ -f /opt/kanidm/data/chain.pem ] && [ -f /opt/kanidm/data/key.pem ]; then
    echo "    Self-signed cert already exists, skipping."
else
    openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
        -keyout /opt/kanidm/data/key.pem \
        -out /opt/kanidm/data/chain.pem \
        -subj "/CN=kanidm-internal" \
        -addext "subjectAltName=DNS:kanidm,DNS:localhost"
    echo "    Self-signed cert generated."
fi
REMOTE_SELFSIGN

echo ""
echo "==> Obtaining Let's Encrypt certificate..."
echo "    Starting temporary nginx for ACME challenge..."
ssh "${VPS_USER}@${VPS_IP}" bash -s -- "$LETSENCRYPT_EMAIL" <<'REMOTE_CERT'
set -euo pipefail

LE_EMAIL="$1"

# Check if cert already exists
if [ -d /opt/kanidm/certs/live/auth.mailbuttons.com ]; then
    echo "    Let's Encrypt cert already exists, skipping."
    exit 0
fi

# Create a minimal nginx config for the ACME challenge only
cat > /opt/kanidm/nginx-acme.conf <<'NGINX'
server {
    listen 80;
    server_name auth.mailbuttons.com;
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    location / {
        return 444;
    }
}
NGINX

# Start temporary nginx for ACME
docker run -d --name acme-nginx \
    -p 80:80 \
    -v /opt/kanidm/nginx-acme.conf:/etc/nginx/conf.d/default.conf:ro \
    -v /opt/kanidm/certbot-webroot:/var/www/certbot:ro \
    nginx:alpine

sleep 2

# Get the certificate
docker run --rm \
    -v /opt/kanidm/certs:/etc/letsencrypt \
    -v /opt/kanidm/certbot-webroot:/var/www/certbot \
    certbot/certbot certonly \
        --webroot -w /var/www/certbot \
        -d auth.mailbuttons.com \
        --email "$LE_EMAIL" \
        --agree-tos \
        --non-interactive

# Clean up temporary nginx
docker stop acme-nginx && docker rm acme-nginx
rm /opt/kanidm/nginx-acme.conf

echo "    Let's Encrypt cert obtained."
REMOTE_CERT

echo ""
echo "==> Starting Kanidm stack..."
ssh "${VPS_USER}@${VPS_IP}" bash -s <<'REMOTE_START'
set -euo pipefail

cd /opt/kanidm
docker compose up -d

echo "    Waiting for Kanidm to initialize..."
sleep 10

echo ""
echo "==> Recovering admin account..."
docker exec kanidm /sbin/kanidmd recover-account admin

echo ""
echo "==> Recovering idm_admin account..."
docker exec kanidm /sbin/kanidmd recover-account idm_admin
REMOTE_START

echo ""
echo "=========================================="
echo "  Deployment complete!"
echo "=========================================="
echo ""
echo "  URL: https://auth.mailbuttons.com"
echo ""
echo "  Save the admin passwords shown above!"
echo "  You can test with:"
echo "    curl -s -o /dev/null -w '%{http_code}' https://auth.mailbuttons.com"
echo ""
