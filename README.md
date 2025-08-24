# docker-portainer-wordpress-lab

Entorno educativo con **Docker**, **Docker Compose**, **Portainer**, **MariaDB**, **PhpMyAdmin** y **WordPress**.  
Incluye scripts para **instalación base**, **despliegue de contenedores**, **conversión de WordPress2 a Stack** y **limpieza total**.

---

## 🚀 Requisitos

- Debian o Ubuntu actualizado.  
- Usuario con privilegios de `root` o `sudo`.  
- Tener instalado `git` y `curl`.  
- Conexión a internet para descargar dependencias e imágenes.  

---

## 🛠️ Pasos para utilizar el Script

### 1- Instalar Git
```bash
sudo apt update && sudo apt install -y git
```
---
### 2- Clonar este repositorio
```bash
git clone https://github.com/LAraujoA/docker-portainer-wordpress-lab.git
cd docker-portainer-wordpress-lab
```
---
### 3- Dar permisos de ejecución a los scripts
```bash
chmod +x setup-portainer.sh
chmod +x deploy-containers.sh
chmod +x purge-containers.sh
chmod +x nuke-docker.sh
```
---
### 4- Instalación base (Docker, Compose, Portainer, IP estática)
```bash
./setup-portainer.sh
```
📌 Verifica en el navegador que el contenedor **Portainer** esté corriendo.

---

### 🔝 5- Despliegue de contenedores (MariaDB, PhpMyAdmin, WordPress1 y WordPress2)
```bash
./deploy-containers.sh
```
Este script:  
- Crea la red **MariadbNet**.  
- Levanta los contenedores:  
  - `mariadb`  
  - `phpmyadmin`  
  - `wordpress1`  
  - `wordpress2`  

En Portainer se verán con `Stack = "--"` (contenedores sueltos), tal como en la práctica.

---
### 6- Convertir solo WordPress2 en Stack en Portainer
1. En Portainer → Contenedores → **elimina** el contenedor `wordpress2` (esto **no borra** los archivos del volumen).  
2. Ve a **Portainer → Stacks → Add stack**  
   - **Name**: `wordpress2`  
   - **Editor**: pega el contenido del archivo `compose/wordpress2.yml` (reutiliza tu volumen y la red existente `MariadbNet`).  
3. Haz click en **Deploy the stack**.  

Ahora WordPress2 estará gestionado como **Stack** en Portainer.

---

### ♻️ 7- Limpieza del laboratorio (reset total)
```bash
# Solo eliminar contenedores y red
./purge-containers.sh

# Eliminar contenedores + imágenes
./purge-containers.sh --prune-images

# Eliminar contenedores + imágenes + datos de volúmenes (DB/WP)
./purge-containers.sh --nuke-data
```

---

### ⛔ 8- Para desinstalar todo Docker + Compose + Portainer (OPCIONAL)
```bash
# Ejecutar el siguiente script
./nuke-dokcer.sh
```

