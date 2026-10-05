#!/usr/bin/env bash
# Escritorio gráfico ligero (XFCE) + Escritorio remoto (xrdp) + VS Code de escritorio
# con la extensión de Claude Code. Acceso por Escritorio remoto de Windows/móvil
# a través de Tailscale (el puerto 3389 NO se abre a Internet).
# Ejecutar como root:  bash escritorio.sh
set -uo pipefail
[ "$(id -u)" = 0 ] || { echo "Ejecuta como root"; exit 1; }
export DEBIAN_FRONTEND=noninteractive
U=ubuntu

echo "== Escritorio XFCE + xrdp =="
apt-get update
apt-get -y install xfce4 xfce4-goodies xorg dbus-x11 xrdp firefox- epiphany-browser
adduser xrdp ssl-cert
echo xfce4-session > /home/$U/.xsession; chown $U /home/$U/.xsession
systemctl enable --now xrdp

echo "== Swap 4 GB (la RAM es de 4 GB) =="
if ! swapon --show | grep -q swapfile; then
  fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "== VS Code (aplicación de escritorio) =="
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
apt-get update && apt-get -y install code
sudo -u $U -H code --install-extension anthropic.claude-code || echo "Instala la extensión 'Claude Code' desde VS Code"

echo "== Solo se permite Escritorio remoto por Tailscale =="
if command -v ufw >/dev/null; then ufw allow in on tailscale0 to any port 3389 proto tcp >/dev/null 2>&1 || true; fi

echo
echo "Listo. Falta poner contraseña al usuario ubuntu para el Escritorio remoto:"
echo "  passwd ubuntu"
echo "Luego conecta con 'Conexión a Escritorio remoto' a la IP de Tailscale del servidor (tailscale ip -4)."
