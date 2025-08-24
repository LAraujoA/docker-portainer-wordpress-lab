#!/usr/bin/env bash
# =====================================================
#  Setup Debian: Docker + Portainer + IP Estática
#  Versión: 1.2 (con validaciones e idempotencia básica)
#  Autor original: Nazarhet
#  Personalización: Luis Araujo (El Mero Dev ⚙️)
#  Fecha: $(date +%F)
# =====================================================

set -euo pipefail

# --- Colores ---
verde="\e[32m"; azul="\e[34m"; amarillo="\e[33m"; rojo="\e[31m"; reset="\e[0m"

# --- Helper: imprimir paso ---
step() { echo -e "${azul}➤ $*${reset}"; }
ok()   { echo -e "${verde}✔ $*${reset}"; }
warn() { echo -e "${amarillo}⚠ $*${reset}"; }
fail() { echo -e "${rojo}❌ $*${reset}"; }

# ================================
# Comprobar root
# ================================
if [[ $EUID -ne 0 ]]; then
  fail "Debes ejecutar este script como root."
  exit 1
fi

# ================================
# Si el script viene en CRLF, auto-fix
# ================================
if file "$0" | grep -q "CRLF"; then
  warn "El script está en formato Windows (CRLF). Corrigiendo..."
  apt-get update -y >/dev/null
  apt-get install -y dos2unix >/dev/null
  dos2unix "$0" >/dev/null
  ok "Formato corregido. Vuelve a ejecutarlo."
  exit 0
fi

# ================================
# Actualizar sistema
# ================================
step "Actualizando el sistema…"
apt-get update -y
apt-get upgrade -y

# ================================
# Instalar herramientas básicas
# ================================
step "Instalando utilidades base…"
apt-get install -y curl wget git unzip zip net-tools htop ufw openssh-server sudo ipcalc ca-certificates gnupg lsb-release

systemctl enable ssh >/dev/null 2>&1 || true
systemctl start ssh  >/dev/null 2>&1 || true
ok "SSH habilitado."

# ================================
# Autodetectar red e IP
# ================================
INTERFAZ=$(ip route | awk '/^default/ {print $5; exit}')
if [[ -z "${INTERFAZ:-}" ]]; then
  fail "No se pudo detectar la interfaz por defecto."
  exit 1
fi

IP_ACTUAL=$(hostname -I | awk '{print $1}')
GATEWAY=$(ip route | awk '/^default/ {print $3; exit}')
MASCARA_CIDR=$(ip -o -f inet addr show "$INTERFAZ" | awk '{print $4}' | cut -d/ -f2)
MASCARA=$(ipcalc "$IP_ACTUAL/$MASCARA_CIDR" | awk -F= '/NETMASK/ {print $2}')

echo -e "${amarillo}Interfaz:${reset} $INTERFAZ"
echo -e "${amarillo}IP detectada:${reset} $IP_ACTUAL"
echo -e "${amarillo}Gateway:${reset} $GATEWAY"
echo -e "${amarillo}Máscara:${reset} $MASCARA"

read -rp "¿Configurar esta IP como estática? (s/n): " resp
if [[ "$resp" =~ ^[Ss]$ ]]; then
  step "Configurando IP estática en /etc/network/interfaces…"
  cp -a /etc/network/interfaces /etc/network/interfaces.bak.$(date +%s)
  cat > /etc/network/interfaces <<EOL
auto lo
iface lo inet loopback

auto $INTERFAZ
iface $INTERFAZ inet static
    address $IP_ACTUAL
    netmask $MASCARA
    gateway $GATEWAY
    dns-nameservers 8.8.8.8 1.1.1.1
EOL
  systemctl restart networking || {
    warn "No se pudo reiniciar 'networking'. Intenta reiniciar el servidor si pierdes conectividad."
  }
  ok "IP estática configurada."
else
  warn "IP estática omitida."
fi

# ================================
# Instalar Docker (script oficial)
# ================================
step "Instalando Docker…"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker >/dev/null 2>&1 || true
  systemctl start docker  >/dev/null 2>&1 || true
  ok "Docker instalado."
else
  ok "Docker ya estaba instalado."
fi

# (Opcional) Instalar Docker Compose plugin si no existe
if ! docker compose version >/dev/null 2>&1; then
  step "Instalando Docker Compose plugin…"
  apt-get install -y docker-compose-plugin || warn "No se pudo instalar docker-compose-plugin. (Opcional)"
fi

# ================================
# Instalar Portainer
# ================================
step "Desplegando Portainer CE…"
docker volume create portainer_data >/dev/null 2>&1 || true

if docker ps -a --format '{{.Names}}' | grep -qx "portainer"; then
  warn "Contenedor 'portainer' ya existe. Saltando despliegue."
else
  docker run -d \
    -p 8000:8000 \
    -p 9443:9443 \
    --name=portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
  ok "Portainer levantado."
fi

# ================================
# Firewall (UFW)
# ================================
step "Configurando firewall (UFW)…"
ufw allow OpenSSH >/dev/null 2>&1 || true
ufw allow 80/tcp   >/dev/null 2>&1 || true
ufw allow 443/tcp  >/dev/null 2>&1 || true
ufw allow 9443/tcp >/dev/null 2>&1 || true
ufw --force enable >/dev/null 2>&1 || true
ok "Reglas UFW aplicadas."

# ================================
# Estructura de carpetas para web
# ================================
step "Creando estructura de trabajo…"
mkdir -p /root/servidor_web/{proyectos,scripts,backups}
ok "Carpetas en /root/servidor_web listas."

# ================================
# Mensaje final
# ================================
clear
ok "Configuración completa, Luis. Misión cumplida. 🚀"
echo -e "${azul}🌐 Portainer (UI): https://$IP_ACTUAL:9443${reset}"
echo -e "${amarillo}📁 Proyectos web: /root/servidor_web${reset}"
echo -e "${azul}By: Nazarhet & Luis Araujo — 'build first, brag later' 💼${reset}"
