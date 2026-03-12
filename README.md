ARSENAL W.A.N. - Hybrid USB Key Deployment Guide

[!] NOTICE FOR WINDOWS & MAC USERS (EASY MODE) > If you are a standard user and just want to create the bootable USB, you do not need to compile anything. Please scroll down to the [Quick Flash Guide (Windows/macOS)](https://www.google.com/search?q=%23quick-flash-guide-windowsmacos) at the bottom of this document to download and flash the pre-built image in 2 minutes.

Environment: Debian Forky / Trixie (Root/SysAdmin Mode)
Target Architecture: Multi-Arch (BIOS Legacy i3/i5 & Modern UEFI x86_64)Method: VFAT + GRUB2 Bridge + Embedded iPXE Auto-Boot

Overview

This guide documents the advanced creation of a "Master USB Key" designed to boot any x86 hardware (legacy or modern) directly into the Arsenal W.A.N. Flat-Root PXE environment.To achieve maximum compatibility and avoid the memdisk e820 memory collision bug on older Intel processors, we utilize a FAT32 (VFAT) partition managed by GRUB2. GRUB detects the motherboard firmware type and loads the appropriate custom-compiled iPXE payload.


Phase 1: Compile Custom iPXE Payloads
We must compile iPXE from source to embed an "Auto-Pilot" script (arranque_automatico.ipxe). This script prevents iPXE from dropping to an interactive shell and forces it to fetch our main deployment menu over DHCP immediately.

1.1 Install Build Dependenciesapt update

apt install -y git build-essential liblzma-dev mtools syslinux syslinux-common

1.2 Clone iPXE Repositorygit clone [https://github.com/ipxe/ipxe.git](https://github.com/ipxe/ipxe.git)

cd ipxe/src

1.3 Create Embedded Auto-Boot ScriptThis file instructs the compiled binary to request an IP and chainload our main menu.cat 

<< 'EOF' > arranque_automatico.ipxe
#!ipxe
echo [!] Arsenal W.A.N. - Requesting DHCP & Locating Master Node...
dhcp
chain [http://pxeboot.1-s.eu/menu.ipxe](http://pxeboot.1-s.eu/menu.ipxe) || shell
EOF

1.4 Compile BIOS and UEFI Binaries
The make command will generate the required files inside newly created bin/ and bin-x86_64-efi/ directories within the ipxe/src/ folder.

#Compile Payload 1: BIOS Legacy (Generates bin/ipxe.lkrn)
make bin/ipxe.lkrn EMBED=arranque_automatico.ipxe
# Compile Payload 2: UEFI 64-bit (Generates bin-x86_64-efi/ipxe.efi)
make bin-x86_64-efi/ipxe.efi EMBED=arranque_automatico.ipxecd bin


Phase 2: Format and Partition the USB Drive

CRITICAL WARNING: Ensure you identify the correct USB drive using lsblk. Running parted or mkfs on the wrong drive (/dev/sda etc.) will result in catastrophic data loss.

cd ~

2.1 Identify and Wipe DriveReplace /dev/sdX with your actual USB device identifier (e.g., /dev/sdc).USB_DRIVE="/dev/sdX"

# Create a clean Master Boot Record (MBR/msdos)
parted -s $USB_DRIVE mklabel msdos
# Create a single FAT32 partition utilizing 100% of the drive
parted -s -a optimal $USB_DRIVE mkpart primary fat32 1MiB 40mb
# Mark the partition as bootable (Active flag)
parted -s $USB_DRIVE set 1 boot on

2.2 Format Partition# Format the newly created partition (Note the '1' appended to the drive path)

mkfs.vfat -F 32 -n "ARSENAL_PXE" ${USB_DRIVE}1


Phase 3: Install GRUB2 Bridge and PayloadsWe install GRUB twice on the same drive: once in the MBR for legacy BIOS, and once in the FAT32 filesystem for UEFI.

3.1 Install GRUB Packages

apt install -y grub-pc-bin grub-efi-amd64-bin

3.2 Mount and Install Bootloaders

mkdir -p /mnt/usb
mount ${USB_DRIVE}1 /mnt/usb
# Install GRUB for BIOS (Writes to MBR of /dev/sdX)
grub-install --target=i386-pc --boot-directory=/mnt/usb/boot --recheck $USB_DRIVE

# Install GRUB for UEFI (Writes to /mnt/usb/EFI/BOOT as removable media)
grub-install --target=x86_64-efi --efi-directory=/mnt/usb --boot-directory=/mnt/usb/boot --removable --recheck

3.3 Transfer Compiled iPXE PayloadsCopy the custom binaries compiled in Phase 1 to the USB drive.(Assuming you are still in the ipxe/src/ directory)

mkdir -p /mnt/usb/boot/ipxe
cp bin/ipxe.lkrn /mnt/usb/boot/ipxe/
cp bin-x86_64-efi/ipxe.efi /mnt/usb/boot/ipxe/

3.4 Create GRUB Bridge ConfigurationThis script acts as the intelligence layer. It detects the firmware environment and executes the corresponding native iPXE 

payload.cat << 'EOF' > /mnt/usb/boot/grub/grub.cfg
set timeout=3
set default=0
set color_normal=cyan/black
set color_highlight=black/cyan

menuentry "[ 1-s.eu | ARSENAL W.A.N. Auto-Boot ]" {
    if [ "${grub_platform}" = "efi" ]; then
        echo ">> Motherboard firmware: UEFI. Bridging to ipxe.efi..."
        chainloader /boot/ipxe/ipxe.efi
    else
        echo ">> Motherboard firmware: BIOS Legacy. Bridging to ipxe.lkrn..."
        linux16 /boot/ipxe/ipxe.lkrn
    fi
}

menuentry "[ Reboot System ]" {
    reboot
}
EOF

3.5 Finalize and Unmountumount /mnt/usb
sync
EOF 


SysAdmin Section. The Master USB Key is now ready. 
SysAdmins can use dd to create an .img backup of this drive to share with users.


Quick Flash Guide (Windows/macOS)

If you just want to use the Arsenal W.A.N. boot key and don't need to compile it from source, follow these simple steps to flash our pre-built image. This image contains everything needed (GRUB dual-boot bridge + auto-connect script) to turn any USB drive into a powerful network boot tool.


Step 1: Download the Required FilesDown

load the Arsenal Image: Grab the latest arsenal-wan-hybrid.img file from [!! HERE !!](https://github.com/1wise/aux.1-s.eu/releases/download/v0.1/arsenal.wan.hybrid.img) our GitHub Releases page. Download a Flashing Tool: We recommend BalenaEtcher because it's safe, free, and works identically on Windows, macOS, and Linux.

[Download BalenaEtcher here](https://www.google.com/search?q=https://etcher.balena.io/)

(Alternatively, Windows users can use [Rufus](https://www.google.com/search?q=https://rufus.ie/))


Step 2: Flash your USB Drive

[!] WARNING: This process will completely erase the USB drive. Make sure you don't have important files on it.Insert your USB drive into your computer.Open BalenaEtcher.Click "Flash from file" and select the arsenal-wan-hybrid.img you downloaded.
Click "Select target" and choose your USB drive. Be very careful to select the correct drive!Click "Flash!". (You might be prompted for administrator privileges).


Step 3: Boot from the USB

Once the flashing is complete, the USB key is ready.Plug it into the target computer (it works on both very old PCs and modern laptops).Turn on the computer and open the Boot Menu (usually F12, F8, F11, or Esc depending on the brand).
Select the USB drive. It will automatically detect your hardware, request an IP address, and load the Arsenal W.A.N. deployment menu.
