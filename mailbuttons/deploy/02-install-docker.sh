#!/usr/bin/env bash
#
# 02-install-docker.sh — Install Docker Engine + Compose on VPS
#
# Run from dev machine. Connects via SSH key auth.
#
# Usage: ./02-install-docker.sh
#
set -euo pipefail

VPS_IP="79.99.45.220"
VPS_USER="root"

echo "==> Installing Docker on $VPS_IP..."

ssh "${VPS_USER}@${VPS_IP}" bash -s <<'REMOTE_SCRIPT'
set -euo pipefail

# Remove any old Docker packages
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    apt-get remove -y "$pkg" 2>/dev/null || true
done

# Install prerequisites
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker apt repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine + Compose plugin
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Create Kanidm directories
mkdir -p /opt/kanidm/data
mkdir -p /opt/kanidm/data/backups
mkdir -p /opt/kanidm/certs
mkdir -p /opt/kanidm/certbot-webroot

echo "==> Docker installed successfully."
docker --version
docker compose version
REMOTE_SCRIPT

echo ""
echo "==> Docker installation complete on $VPS_IP."
