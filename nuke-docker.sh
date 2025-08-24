#!/usr/bin/env bash
set -e

echo "🛑 Deteniendo Docker..."
systemctl stop docker || true
systemctl stop docker.socket || true

echo "🗑️ Desinstalando Docker y plugins..."
apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || true
apt-get autoremove -y --purge

echo "🧹 Borrando directorios..."
rm -rf /var/lib/docker /var/lib/containerd

echo "🗑️ Borrando volumen de Portainer..."
docker volume rm portainer_data 2>/dev/null || true

echo "✅ Sistema limpio: Docker y Portainer eliminados completamente."