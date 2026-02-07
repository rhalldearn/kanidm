#!/usr/bin/env bash
#
# 01-harden-server.sh — Initial server hardening for auth.mailbuttons.com
#
# Run from dev machine. Uses sshpass for initial password-based login,
# then sets up key auth and disables password login.
#
# Usage: ./01-harden-server.sh
#
set -euo pipefail

VPS_IP="79.99.45.220"
VPS_USER="root"
SSH_PUBKEY="$HOME/.ssh/id_ed25519.pub"

if [ ! -f "$SSH_PUBKEY" ]; then
    echo "ERROR: SSH public key not found at $SSH_PUBKEY"
    exit 1
fi

if ! command -v sshpass &>/dev/null; then
    echo "Installing sshpass..."
    sudo apt-get install -y sshpass
fi

read -rsp "Enter VPS root password: " VPS_PASS
echo

PUBKEY_CONTENT=$(cat "$SSH_PUBKEY")

echo "==> Connecting to $VPS_IP to set up SSH key and harden server..."

sshpass -p "$VPS_PASS" ssh -o StrictHostKeyChecking=accept-new "${VPS_USER}@${VPS_IP}" bash -s <<REMOTE_SCRIPT
set -euo pipefail

echo "==> Installing SSH public key..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "${PUBKEY_CONTENT}" >> ~/.ssh/authorized_keys
sort -u -o ~/.ssh/authorized_keys ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

echo "==> Hardening SSH configuration..."
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

echo "==> Configuring firewall (ufw)..."
apt-get update -qq
apt-get install -y -qq ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment "SSH"
ufw allow 80/tcp comment "HTTP (certbot)"
ufw allow 443/tcp comment "HTTPS"
echo "y" | ufw enable

echo "==> Installing unattended-upgrades..."
apt-get install -y -qq unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "==> Setting timezone to UTC..."
timedatectl set-timezone UTC

echo "==> Server hardening complete."
REMOTE_SCRIPT

echo ""
echo "==> Verifying key-based SSH access..."
if ssh -o BatchMode=yes -o ConnectTimeout=10 "${VPS_USER}@${VPS_IP}" "echo 'Key-based SSH works!'"; then
    echo "==> SUCCESS: Key-based authentication is working."
else
    echo "ERROR: Key-based SSH failed. Check your key setup."
    exit 1
fi

echo ""
echo "==> Verifying password auth is disabled..."
if sshpass -p "$VPS_PASS" ssh -o BatchMode=no -o PreferredAuthentications=password -o PubkeyAuthentication=no "${VPS_USER}@${VPS_IP}" "echo 'FAIL'" 2>/dev/null; then
    echo "WARNING: Password authentication still appears to work."
else
    echo "==> CONFIRMED: Password authentication is disabled."
fi

echo ""
echo "Done! Server at $VPS_IP is hardened."
