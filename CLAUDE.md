# WEBOS — servidor de desarrollo de Christiam (Grupo IGS)

Proyecto para montar y operar el servidor de desarrollo remoto "webos" hasta migrar a una VM
gratuita Oracle A1. Responde siempre en español.

> Este repositorio es PÚBLICO. Nunca escribas aquí contraseñas, tokens, claves API ni llaves SSH.

## Infraestructura

| Recurso | Dato |
|---|---|
| Proveedor | Hetzner Cloud, proyecto "webos" |
| Servidor | `webos` (id 168795282), CX33: 4 vCPU x86 / 8 GB / 80 GB, Núremberg |
| IP pública | 46.224.121.89 (cortafuegos Hetzner "solo-ssh": solo 22/tcp + ICMP) |
| IP Tailscale | 100.124.101.66 (Tailscale con `--ssh` activado) |
| Coste | ~10,59 $/mes, encendido 24/7 (Hetzner cobra igual apagado) |
| SO | Ubuntu 24.04 LTS |
| Usuario de trabajo | `ubuntu` (sudo sin contraseña), proyectos en `~/proyectos` |

Acceso desde el PC: `ssh ubuntu@100.124.101.66` (vía Tailscale; el PC debe estar en la misma tailnet).
Acceso de emergencia: consola web de Hetzner (root; contraseña con Rescue → Reset root password).

### Instalado en webos
- Seguridad: SSH solo con clave y sin root, fail2ban, unattended-upgrades.
- VS Code CLI (`/usr/local/bin/code`, para `code tunnel`) y VS Code escritorio (`/usr/bin/code`) con la extensión Claude Code.
- Claude Code (`~/.local/bin/claude`), Tailscale, FortiClient 7.4.3, Google Chrome.
- XFCE + xrdp + swap 4 GB (el escritorio remoto se descartó por el lag desde Colombia; se puede desinstalar).

## Forma de trabajo decidida
1. **Claude Code en el servidor por Remote Control**, una sesión por proyecto, como servicios
   permanentes (arrancan solos tras reiniciar). Se usan desde la app de Claude (móvil o web).
2. **VS Code por túnel** (`code tunnel service install` → vscode.dev) para ver o editar código y hacer
   SQL con la extensión MSSQL (SSMS no existe en Linux).
3. Las VPN de clientes se manejan por línea de comandos (FortiClient CLI u openfortivpn) en split tunnel
   para no romper Tailscale.

## Oracle Cloud (objetivo: migrar gratis)
- Tenancy "chnavarro", región de origen `us-ashburn-1` (única suscrita). Las A1 gratis solo se crean ahí.
- Límite gratuito A1 de la cuenta: **2 OCPU / 12 GB en total**.
- Existe una VM `openclaw-micro` (E2.1.Micro): **no tocarla**.
- `oracle/crear-vm-a1.sh`: reintenta crear la A1 (SIZES="2:12 1:6") en los 3 dominios de disponibilidad cada 60 s, y detecta si ya existe una.
- Hasta ahora ha dado ~130 intentos con "Out of host capacity".
- **Pendiente:** montar ese bucle como servicio systemd EN webos. Para ello hay que generar una clave API nueva
  en el servidor y subirla con Oracle Cloud Shell: `oci iam user api-key upload --user-id <user OCID> --key-file <pem>`.
  Cuando salga la A1: esperar su cloud-init, copiar `/home/ubuntu` con rsync y avisar con la IP.
  NO borrar Hetzner sin confirmación.

## Scripts del repo
- `oracle/crear-vm-a1.sh`: bucle de creación de la A1.
- `oracle/post-setup.sh`: endurecimiento + VS Code CLI + Claude Code (cloud-init de la A1).
- `servidor/instalar-todo.sh`: VS Code CLI, Claude Code, Tailscale y FortiClient.
- `servidor/escritorio.sh`: XFCE + xrdp + VS Code escritorio (ya no se usa).

## Tareas pendientes (en orden)
1. En webos: `code tunnel service install` y Claude Code en Remote Control como servicio (por proyecto).
2. Bucle de Oracle como servicio en webos (ver arriba).
3. Opcional: desinstalar XFCE/xrdp para liberar RAM.
4. Traer el proyecto PROS (vault de contraseñas, `E:\00_CLAUDE\PRJ\PROS`) y evaluar su cifrado.
5. Configurar las VPN de clientes en FortiClient o openfortivpn.
6. Limpieza de seguridad (la hará Christiam): rotar las credenciales que se pegaron en el chat:
   - token de Hetzner;
   - claves de AWS de igs-admin;
   - clave API de Oracle con huella 0e:51:…;
   - contraseñas de root y de ubuntu.

## MINI (asistente personal) — reglas
- MINI (OpenClaw, Lightsail `san-alonso-agent`, Tailscale 100.109.230.42) recibe el estado de las sesiones de
  Claude Code y avisa a Christiam por WhatsApp. **No modificar nada de MINI** salvo petición explícita.
- Puede que Christiam no mire la pantalla: si necesitas una decisión, termina con una pregunta clara y corta.
- Describe cada comando con claridad al pedir permiso (Christiam lo lee en el móvil).
- Los deploys los hace Christiam. Pide confirmación antes de cualquier cosa que cueste dinero o que borre algo.

## Formato de informes
Siempre en tres secciones, cortas y gerenciales:
**Lo hecho:** / **Lo pendiente:** / **Lo que necesito de ti:**
