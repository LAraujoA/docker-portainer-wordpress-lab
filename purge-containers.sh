#!/bin/bash
set -e

# === RUTAS DE VOLÚMENES (ajústalas si usaste otras) =========================
DB_VOL="/volume2/Docker/Mariadb/mysql"
WP1_VOL="/volume2/Docker/wordpress1"
WP2_VOL="/volume2/Docker/wordpress2"

echo "[1/4] Parando y eliminando contenedores si existen..."
for c in Mariadb PhpMyAdmin wordpress1 wordpress2; do
  if docker ps -a --format '{{.Names}}' | grep -q "^${c}$"; then
    docker rm -f "$c" || true
    echo " - $c eliminado."
  else
    echo " - $c no existe, ok."
  fi
done

echo "[2/4] Eliminando red MariadbNet si existe..."
if docker network ls --format '{{.Name}}' | grep -q '^MariadbNet$'; then
  docker network rm MariadbNet || true
  echo " - Red MariadbNet eliminada."
else
  echo " - Red MariadbNet no existe, ok."
fi

# (Opcional) eliminar imágenes relacionadas
if [[ "$1" == "--prune-images" ]]; then
  echo "[3/4] Eliminando imágenes relacionadas (opcional)..."
  docker image rm -f mariadb:10.6 phpmyadmin/phpmyadmin:latest wordpress:6.8.0-php8.3-apache wordpress:6.7.2-php8.1-apache || true
else
  echo "[3/4] Saltando eliminación de imágenes. (Usa --prune-images para forzar)"
fi

# (OPCIONAL y DESTRUCTIVO) borrar carpetas de datos
if [[ "$1" == "--nuke-data" || "$2" == "--nuke-data" ]]; then
  echo "[4/4] BORRANDO DATOS en host (DB y WP). Esto es irreversible en estas rutas:"
  echo "      $DB_VOL"
  echo "      $WP1_VOL"
  echo "      $WP2_VOL"
  read -p "¿Seguro? escribe SI en mayúsculas: " yn
  if [[ "$yn" == "SI" ]]; then
    sudo rm -rf "$DB_VOL" "$WP1_VOL" "$WP2_VOL"
    echo " - Datos eliminados."
  else
    echo " - Cancelado. No se borraron datos."
  fi
else
  echo "[4/4] Manteniendo datos en host. (Usa --nuke-data para borrarlos)"
fi

echo "Cleanup terminado."
