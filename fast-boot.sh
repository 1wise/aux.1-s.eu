#!/usr/bin/env bash

# ==============================================================================
# boot-fast.sh
# Descarga paralela masiva, extracción al vuelo y enrutamiento inteligente
# Adaptado para evitar llenar la partición root (trabajando en /var/www/)
# ACTUALIZACIÓN: Verificación de versiones. Solo descarga y extrae si hay cambios (Timestamping)
# ==============================================================================

# Directorio de trabajo principal (Donde hay espacio, partición WEB)
WORK_DIR="/var/www/html/boot"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Iniciando sincronización masiva e inteligente en $WORK_DIR...${NC}"

# 1. Comprobar dependencias (añadimos 'stat' que suele venir en coreutils)
for cmd in wget tar unzip rsync stat; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}❌ Falta $cmd. Instálalo con: apt install $cmd${NC}"
        exit 1
    fi
done

mkdir -p "$WORK_DIR"

# 2. Lista cruda de enlaces
RAW_URLS="
https://deb.debian.org/debian/dists/trixie/main/installer-amd64/current/images/netboot/gtk/netboot.tar.gz
https://deb.debian.org/debian/dists/trixie/main/installer-amd64/current/images/netboot/netboot.tar.gz
https://deb.debian.org/debian/dists/trixie/main/installer-arm64/current/images/netboot/gtk/netboot.tar.gz
https://deb.debian.org/debian/dists/trixie/main/installer-arm64/current/images/netboot/mini.iso
https://cdimage.debian.org/cdimage/release/13.3.0/amd64/iso-cd/SHA256SUMS
https://cdimage.debian.org/cdimage/release/13.3.0/amd64/iso-cd/SHA256SUMS.sign
https://cdimage.debian.org/cdimage/release/13.3.0/amd64/iso-cd/debian-13.3.0-amd64-netinst.iso
https://cdimage.debian.org/cdimage/release/13.3.0/amd64/iso-cd/debian-mac-13.3.0-amd64-netinst.iso
https://cdimage.debian.org/cdimage/release/13.3.0/arm64/iso-cd/SHA256SUMS
https://cdimage.debian.org/cdimage/release/13.3.0/arm64/iso-cd/SHA256SUMS.sign
https://cdimage.debian.org/cdimage/release/13.3.0/arm64/iso-cd/debian-13.3.0-arm64-netinst.iso
https://cdimage.debian.org/cdimage/daily-builds/daily/current/amd64/iso-cd/SHA256SUMS
https://cdimage.debian.org/cdimage/daily-builds/daily/current/amd64/iso-cd/SHA256SUMS.sign
https://cdimage.debian.org/cdimage/daily-builds/daily/current/amd64/iso-cd/debian-edu-testing-amd64-netinst.iso
https://cdimage.debian.org/cdimage/daily-builds/daily/current/amd64/iso-cd/debian-testing-amd64-netinst.iso
https://cdimage.debian.org/cdimage/daily-builds/daily/current/arm64/iso-cd/SHA256SUMS
https://cdimage.debian.org/cdimage/daily-builds/daily/current/arm64/iso-cd/SHA256SUMS.sign
https://cdimage.debian.org/cdimage/daily-builds/daily/current/arm64/iso-cd/debian-testing-arm64-netinst.iso
https://boot.netboot.xyz/ipxe/netboot.xyz.kpxe
https://boot.netboot.xyz/ipxe/netboot.xyz.efi
https://boot.netboot.xyz/ipxe/netboot.xyz-arm64.efi
https://distfiles.gentoo.org/releases/amd64/autobuilds/20260215T164556Z/install-amd64-minimal-20260215T164556Z.iso
https://distfiles.gentoo.org/releases/amd64/autobuilds/20260215T164556Z/livegui-amd64-20260215T164556Z.iso
https://distfiles.gentoo.org/releases/amd64/autobuilds/20260222T170100Z/di-amd64-cloudinit-20260222T170100Z.qcow2
https://distfiles.gentoo.org/releases/amd64/autobuilds/20260222T170100Z/di-amd64-console-20260222T170100Z.qcow2
https://releases.ubuntu.com/25.10/SHA256SUMS
https://releases.ubuntu.com/25.10/SHA256SUMS.gpg
https://releases.ubuntu.com/25.10/ubuntu-25.10-desktop-amd64.iso
https://releases.ubuntu.com/25.10/ubuntu-25.10-desktop-amd64.iso.torrent
https://releases.ubuntu.com/25.10/ubuntu-25.10-desktop-amd64.iso.zsync
https://releases.ubuntu.com/25.10/ubuntu-25.10-desktop-amd64.list
https://releases.ubuntu.com/25.10/ubuntu-25.10-desktop-amd64.manifest
https://releases.ubuntu.com/25.10/ubuntu-25.10-live-server-amd64.iso
https://releases.ubuntu.com/25.10/ubuntu-25.10-live-server-amd64.iso.torrent
https://releases.ubuntu.com/25.10/ubuntu-25.10-live-server-amd64.iso.zsync
https://releases.ubuntu.com/25.10/ubuntu-25.10-live-server-amd64.list
https://releases.ubuntu.com/25.10/ubuntu-25.10-live-server-amd64.manifest
https://releases.ubuntu.com/25.10/ubuntu-25.10-netboot-amd64.tar.gz
https://releases.ubuntu.com/25.10/ubuntu-25.10-wsl-amd64.manifest
https://releases.ubuntu.com/25.10/ubuntu-25.10-wsl-amd64.wsl
https://releases.ubuntu.com/24.04/SHA256SUMS
https://releases.ubuntu.com/24.04/SHA256SUMS.gpg
https://releases.ubuntu.com/24.04/ubuntu-24.04.3-desktop-amd64.iso
https://releases.ubuntu.com/24.04/ubuntu-24.04.3-desktop-amd64.iso.torrent
https://releases.ubuntu.com/24.04/ubuntu-24.04.3-desktop-amd64.iso.zsync
https://releases.ubuntu.com/24.04/ubuntu-24.04.3-desktop-amd64.list
https://releases.ubuntu.com/24.04/ubuntu-24.04.3-desktop-amd64.manifest
https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.iso
https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.iso.torrent
https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.iso.zsync
https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.list
https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.manifest
https://releases.ubuntu.com/24.04/ubuntu-24.04.3-netboot-amd64.tar.gz
https://releases.ubuntu.com/24.04/ubuntu-24.04.3-wsl-amd64.manifest
https://releases.ubuntu.com/24.04/ubuntu-24.04.3-wsl-amd64.wsl
https://releases.ubuntu.com/24.04/ubuntu-24.04.4-desktop-amd64.iso
https://releases.ubuntu.com/24.04/ubuntu-24.04.4-desktop-amd64.iso.torrent
https://releases.ubuntu.com/24.04/ubuntu-24.04.4-desktop-amd64.iso.zsync
https://releases.ubuntu.com/24.04/ubuntu-24.04.4-desktop-amd64.list
https://releases.ubuntu.com/24.04/ubuntu-24.04.4-desktop-amd64.manifest
https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.iso
https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.iso.torrent
https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.iso.zsync
https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.list
https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.manifest
https://releases.ubuntu.com/24.04/ubuntu-24.04.4-netboot-amd64.tar.gz
https://releases.ubuntu.com/24.04/ubuntu-24.04.4-wsl-amd64.manifest
https://releases.ubuntu.com/24.04/ubuntu-24.04.4-wsl-amd64.wsl
https://geo.mirror.pkgbuild.com/iso/latest/arch/boot/x86_64/vmlinuz-linux
https://geo.mirror.pkgbuild.com/iso/latest/arch/boot/x86_64/initramfs-linux.img
https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/netboot/vmlinuz-lts
https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/netboot/initramfs-lts
https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/netboot/modloop-lts
https://archlinux.org/static/netboot/ipxe-arch.lkrn
https://archlinux.org/static/netboot/ipxe-arch.lkrn.sig
https://archlinux.org/static/netboot/ipxe-arch.pxe
https://archlinux.org/static/netboot/ipxe-arch.pxe.sig
https://archlinux.org/static/netboot/ipxe-arch.efi
https://archlinux.org/static/netboot/ipxe-arch.efi.sig
https://ftp.rediris.es/mirror/archlinux/iso/2026.03.01/archlinux-x86_64.iso
https://ftp.rediris.es/mirror/archlinux/iso/2026.03.01/archlinux-x86_64.iso.sig
https://ftp.rediris.es/mirror/archlinux/iso/2026.03.01/b2sums.txt
https://ftp.rediris.es/mirror/archlinux/iso/2026.03.01/sha256sums.txt
https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-standard-3.23.3-x86_64.iso
https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-standard-3.23.3-x86_64.iso.sha256
https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-standard-3.23.3-x86_64.iso.asc
https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-netboot-3.23.3-x86_64.tar.gz
https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-netboot-3.23.3-x86_64.tar.gz.sha256
https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-netboot-3.23.3-x86_64.tar.gz.asc
https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-minirootfs-3.23.3-x86_64.tar.gz
https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-minirootfs-3.23.3-x86_64.tar.gz.sha256
https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86/alpine-minirootfs-3.23.3-x86.tar.gz
https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86/alpine-minirootfs-3.23.3-x86.tar.gz.sha256
https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86/alpine-minirootfs-3.23.3-x86.tar.gz.asc
https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-virt-3.23.3-x86_64.iso
https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-virt-3.23.3-x86_64.iso.sha256
https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-virt-3.23.3-x86_64.iso.asc
"

# 3. Enrutador Inteligente (Calcula la ruta de destino analizando la URL)
get_dest() {
    local u="$1"
    local base=$(basename "$u")

    # Debian
if [[ "$u" == *"debian/dists/trixie/main/installer-amd64/current/images/netboot/gtk"* ]]; then echo "debian/trixie/amd64/gtk/$base"
    elif [[ "$u" == *"debian/dists/trixie/main/installer-amd64/current/images/netboot"* ]]; then echo "debian/trixie/amd64/$base"
    elif [[ "$u" == *"debian/dists/trixie/main/installer-arm64/current/images/netboot"* ]]; then echo "debian/trixie/arm64/$base"
    elif [[ "$u" == *"debian/dists/trixie/main/installer-arm64/current/images/netboot/gtk/"* ]]; then echo "debian/trixie/arm64/gtk/$base"
    elif [[ "$u" == *"release/13.3.0/amd64"* ]]; then echo "debian/13.3.0/amd64/$base"
    elif [[ "$u" == *"release/13.3.0/arm64"* ]]; then echo "debian/13.3.0/arm64/$base"
    elif [[ "$u" == *"daily-builds/daily/current/amd64"* ]]; then echo "debian/testing/amd64/$base"
    elif [[ "$u" == *"daily-builds/daily/current/arm64"* ]]; then echo "debian/testing/arm64/$base"

    # Ubuntu
    elif [[ "$u" == *"ubuntu.com/25.10"* ]]; then echo "ubuntu/25.10/$base"
    elif [[ "$u" == *"ubuntu.com/24.04-4"* ]]; then echo "ubuntu/24.04-4/$base"

    # Gentoo
    elif [[ "$u" == *"distfiles.gentoo.org"* ]]; then echo "gentoo/$base"

    # Arch Linux
    elif [[ "$u" == *"pkgbuild.com/iso/latest/arch"* ]] || [[ "$u" == *"archlinux.org/static/netboot"* ]] || [[ "$u" == *"rediris.es/mirror/archlinux"* ]]; then echo "arch/$base"

    # Alpine Linux
    elif [[ "$u" == *"alpinelinux.org/alpine/v3.19"* ]]; then echo "alpine/v3.19/$base"
    elif [[ "$u" == *"alpinelinux.org/alpine/v3.23/releases/x86_64"* ]]; then echo "alpine/v3.23/x86_64/$base"
    elif [[ "$u" == *"alpinelinux.org/alpine/v3.23/releases/x86"* ]]; then echo "alpine/v3.23/x86/$base"
    
    # Herramientas / Netboot
    elif [[ "$u" == *"boot.netboot.xyz"* ]]; then echo "tools/$base"
    
    # Por defecto
    else echo "misc/$base"
    fi
}

# 4. Limpiamos duplicados y líneas vacías de la lista original
UNIQUE_URLS=$(echo "$RAW_URLS" | grep '^http' | sort -u)

# 5. Motor de Descarga (Controlado: 15 descargas paralelas max)
job_count=0
echo -e "${YELLOW}⬇️  Comprobando actualizaciones de archivos en $WORK_DIR...${NC}"

for url in $UNIQUE_URLS; do
    dest_rel=$(get_dest "$url")
    file_path="$WORK_DIR/$dest_rel"
    dir_path=$(dirname "$file_path")
    
    mkdir -p "$dir_path"
    
    (
        # Obtenemos la fecha de modificación del archivo local (si no existe, devolverá 0)
        mod_before=$(stat -c %Y "$file_path" 2>/dev/null || echo "0")
        
        # Wget con Timestamping (-N) y prefijo de directorio (-P).
        # Solo descargará el archivo si el servidor remoto tiene una versión más nueva o si no existe.
        wget -q -N -P "$dir_path" -U "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "$url"
        
        # Obtenemos la fecha después de la ejecución de Wget
        mod_after=$(stat -c %Y "$file_path" 2>/dev/null || echo "0")
        
        if [[ "$mod_after" == "0" ]]; then
            echo -e "${RED}❌ Error (No encontrado/Fallido):${NC} $url"
        elif [[ "$mod_before" != "$mod_after" ]]; then
            echo -e "${GREEN}✅ Nuevo/Actualizado:${NC} $(basename "$file_path") -> ${BLUE}$dir_path${NC}"
            
            # Solo realizamos la extracción si el archivo de origen ha cambiado o es nuevo
            if [[ "$file_path" == *.tar.gz ]]; then
                tar -xzf "$file_path" -C "$dir_path"
                echo -e "${YELLOW}📦 Extraído Netboot:${NC} $(basename "$file_path")"
            fi
        else
            # El archivo ya está en su última versión, lo indicamos sin hacer ruido
            echo -e "${NC}⏭️  Al día (Omitido):${NC} $(basename "$file_path")"
        fi
    ) &

    # Control de concurrencia para no ahogar la red
    ((job_count++))
    if (( job_count >= 15 )); then
        wait -n # Espera a que termine al menos una tarea antes de lanzar la siguiente
        ((job_count--))
    fi
done

# Esperamos a que los últimos hilos terminen
wait

echo -e "\n${BLUE}⚙️  Exponiendo ISOs, QCOW2 y netboots en la raíz (usando Hardlinks para ahorrar 100% de espacio)...${NC}"

# Utilizamos 'ln -f' (enlaces duros) en lugar de 'cp'. 
# Esto hace que el archivo esté accesible desde la raíz pero sin gastar ni un solo Megabyte extra.
find "$WORK_DIR" -mindepth 2 -type f \( -name "*.iso" -o -name "*.qcow2" -name "*.gz" -name "*.torrent" \) -exec ln -f {} "$WORK_DIR/" \;

echo -e "${GREEN}🎉 ¡Sincronización Inteligente Finalizada! Ecosistema actualizado con éxito.${NC}"
