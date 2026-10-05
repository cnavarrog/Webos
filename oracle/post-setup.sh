#!/usr/bin/env bash
# Se ejecuta EN la VM (como cloud-init/root o como ubuntu con sudo): endurece el servidor e instala
# VS Code (CLI con túnel remoto, ARM64) y Claude Code.
set -euo pipefail

# --- Actualizaciones y seguridad
sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install fail2ban unattended-upgrades curl git
sudo dpkg-reconfigure -f noninteractive unattended-upgrades

# SSH solo con clave, sin root
sudo tee /etc/ssh/sshd_config.d/99-hardening.conf >/dev/null <<'CONF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
X11Forwarding no
CONF
sudo systemctl restart ssh

# fail2ban para SSH
sudo tee /etc/fail2ban/jail.local >/dev/null <<'CONF'
[sshd]
enabled = true
maxretry = 5
bantime = 1h
CONF
sudo systemctl enable --now fail2ban
# Las imágenes Ubuntu de Oracle ya traen iptables que solo abren el 22; no se añade ufw
# para no romper las reglas de OCI.

# --- VS Code CLI (ARM64): permite conectarte desde tu VS Code vía "code tunnel"
curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-arm64" -o /tmp/vscode-cli.tar.gz
sudo tar -xzf /tmp/vscode-cli.tar.gz -C /usr/local/bin && rm /tmp/vscode-cli.tar.gz

# --- Claude Code
sudo -u ubuntu -H bash -c 'curl -fsSL https://claude.ai/install.sh | bash' || true

echo "Listo. Ejecuta 'code tunnel' para enlazar VS Code y 'claude' para Claude Code."
