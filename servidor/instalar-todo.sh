#!/usr/bin/env bash
# Instala en el servidor (Ubuntu 24.04, x86 o ARM): VS Code (CLI con túnel),
# Claude Code, Tailscale y FortiClient VPN (o openfortivpn si no hay paquete).
# Ejecutar como root:  bash instalar-todo.sh
set -uo pipefail
[ "$(id -u)" = 0 ] || { echo "Ejecuta como root (sudo -i)"; exit 1; }
U=ubuntu
id "$U" >/dev/null 2>&1 || { useradd -m -s /bin/bash -G sudo "$U"; echo "$U ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$U; }
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install curl git ca-certificates

echo "== VS Code CLI =="
case "$(uname -m)" in aarch64) A=arm64 ;; *) A=x64 ;; esac
command -v code >/dev/null || { curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-$A" -o /tmp/code.tgz && tar -xzf /tmp/code.tgz -C /usr/local/bin && rm /tmp/code.tgz; }
code --version | head -1

echo "== Claude Code =="
sudo -u "$U" -H bash -c 'command -v claude >/dev/null || ~/.local/bin/claude --version >/dev/null 2>&1 || curl -fsSL https://claude.ai/install.sh | bash'
grep -q '.local/bin' /home/$U/.bashrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/$U/.bashrc

echo "== Tailscale =="
command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh
systemctl enable --now tailscaled

echo "== FortiClient VPN =="
if [ "$A" = x64 ] && ! command -v forticlient >/dev/null; then
  curl -fsSL -o /tmp/forticlient.deb https://links.fortinet.com/forticlient/deb/vpnagent \
    && DEBIAN_FRONTEND=noninteractive apt-get -y install /tmp/forticlient.deb \
    || echo "No se pudo instalar FortiClient oficial; se usará openfortivpn"
  rm -f /tmp/forticlient.deb
fi
command -v forticlient >/dev/null || DEBIAN_FRONTEND=noninteractive apt-get -y install openfortivpn

echo
echo "Listo. Siguientes pasos (como root):"
echo "  tailscale up --ssh              # abre el enlace que muestra para unir el servidor a tu Tailscale"
echo "  su - $U -c 'code tunnel'        # enlaza VS Code (vscode.dev) con tu cuenta de GitHub"
echo "  su - $U  ->  claude             # Claude Code"
