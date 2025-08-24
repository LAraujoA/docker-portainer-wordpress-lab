#!/bin/bash
set -euo pipefail

# === Parámetros (ajusta rutas si quieres) =========================
NETWORK="MariadbNet"

DB_ROOT_PASS="12345"

DB_VOL="/volume2/Docker/Mariadb/mysql"
WP1_VOL="/volume2/Docker/wordpress1"
WP2_VOL="/volume2/Docker/wordpress2"

# Credenciales/DBs según la guía del docente
WP1_DB="wordpress1"
WP1_USER="wpuser1"
WP1_PASS="wppass1"

WP2_DB="wordpress2"
WP2_USER="wpuser2"
WP2_PASS="wppass2"

# === Helpers ======================================================
exists_container() { docker ps -a --format '{{.Names}}' | grep -q "^$1$"; }
rm_if_exists()    { exists_container "$1" && docker rm -f "$1" >/dev/null 2>&1 || true; }

msg() { echo -e "\n==> $*"; }

# === Pre-chequeos =================================================
command -v docker >/dev/null || { echo "Docker no está instalado."; exit 1; }

# Crear rutas de datos
sudo mkdir -p "$DB_VOL" "$WP1_VOL" "$WP2_VOL"

# Crear red si no existe
msg "Creando red ${NETWORK} (si no existe)..."
docker network inspect "$NETWORK" >/dev/null 2>&1 || docker network create --driver bridge "$NETWORK"

# === MariaDB ======================================================
msg "Lanzando MariaDB (3306:3306)..."
rm_if_exists Mariadb
docker run -d \
  --name Mariadb \
  --network "$NETWORK" \
  --restart unless-stopped \
  -e MARIADB_ROOT_PASSWORD="${DB_ROOT_PASS}" \
  -p 3306:3306 \
  -v "${DB_VOL}":/var/lib/mysql \
  mariadb:10.6

# Esperar a que MariaDB responda
msg "Esperando a que MariaDB esté listo..."
for i in {1..60}; do
  if docker exec Mariadb sh -c "mysqladmin ping -h 127.0.0.1 -p${DB_ROOT_PASS} --silent" >/dev/null 2>&1; then
    break
  fi
  sleep 1
  if [ "$i" -eq 60 ]; then
    echo "MariaDB no respondió a tiempo."; exit 1
  fi
done

# Crear DBs y usuarios con @'%'
msg "Creando bases y usuarios (con permisos @'%')..."
docker exec -i Mariadb sh -c "mysql -uroot -p${DB_ROOT_PASS}" <<SQL
CREATE DATABASE IF NOT EXISTS ${WP1_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS ${WP2_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${WP1_USER}'@'%' IDENTIFIED BY '${WP1_PASS}';
CREATE USER IF NOT EXISTS '${WP2_USER}'@'%' IDENTIFIED BY '${WP2_PASS}';

GRANT ALL PRIVILEGES ON ${WP1_DB}.* TO '${WP1_USER}'@'%';
GRANT ALL PRIVILEGES ON ${WP2_DB}.* TO '${WP2_USER}'@'%';
FLUSH PRIVILEGES;
SQL

# === phpMyAdmin ===================================================
msg "Lanzando phpMyAdmin (38002:80)..."
rm_if_exists PhpMyAdmin
docker run -d \
  --name PhpMyAdmin \
  --network "$NETWORK" \
  --restart unless-stopped \
  -p 38002:80 \
  -e PMA_HOST=Mariadb \
  -e PMA_PORT=3306 \
  phpmyadmin/phpmyadmin:latest

# === WordPress 1 ==================================================
msg "Lanzando WordPress 1 (38101:80)..."
rm_if_exists wordpress1
docker run -d \
  --name wordpress1 \
  --network "$NETWORK" \
  --restart unless-stopped \
  -e WORDPRESS_DB_HOST=Mariadb \
  -e WORDPRESS_DB_USER="${WP1_USER}" \
  -e WORDPRESS_DB_PASSWORD="${WP1_PASS}" \
  -e WORDPRESS_DB_NAME="${WP1_DB}" \
  -v "${WP1_VOL}":/var/www/html \
  -p 38101:80 \
  wordpress:6.8.0-php8.3-apache

# === WordPress 2 ==================================================
msg "Lanzando WordPress 2 (80:80)..."
rm_if_exists wordpress2
docker run -d \
  --name wordpress2 \
  --network "$NETWORK" \
  --restart unless-stopped \
  -e WORDPRESS_DB_HOST=Mariadb \
  -e WORDPRESS_DB_USER="${WP2_USER}" \
  -e WORDPRESS_DB_PASSWORD="${WP2_PASS}" \
  -e WORDPRESS_DB_NAME="${WP2_DB}" \
  -v "${WP2_VOL}":/var/www/html \
  -p 80:80 \
  wordpress:6.7.2-php8.1-apache

msg "Listo 🎉"
echo "
- phpMyAdmin:   http://<IP-VM>:38002  (root / ${DB_ROOT_PASS})
- WordPress 1:  http://<IP-VM>:38101
- WordPress 2:  http://<IP-VM>       (puerto 80)
En Portainer verás Stack='-' y MariaDB publicado como 3306:3306.
"
