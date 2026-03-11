ARSENAL W.A.N. - Hybrid USB Key Deployment GuideEnvironment: Debian Forky / Trixie (Root/SysAdmin Mode)Target Architecture: Multi-Arch (BIOS Legacy i3/i5 & Modern UEFI x86_64)Method: VFAT + GRUB2 Bridge + Embedded iPXE Auto-BootOverviewThis guide documents the creation of a "Master USB Key" designed to boot any x86 hardware (legacy or modern) directly into the Arsenal W.A.N. Flat-Root PXE environment.To achieve maximum compatibility and avoid the memdisk e820 memory collision bug on older Intel processors, we utilize a FAT32 (VFAT) partition managed by GRUB2. GRUB detects the motherboard firmware type and loads the appropriate custom-compiled iPXE payload.Phase 1: Compile Custom iPXE PayloadsWe must compile iPXE from source to embed an "Auto-Pilot" script (arranque_automatico.ipxe). This script prevents iPXE from dropping to an interactive shell and forces it to fetch our main deployment menu over DHCP immediately.1.1 Install Build Dependenciesapt update
apt install -y git build-essential liblzma-dev mtools syslinux syslinux-common
1.2 Clone iPXE Repositorygit clone [https://github.com/ipxe/ipxe.git](https://github.com/ipxe/ipxe.git)
cd ipxe/src
1.3 Create Embedded Auto-Boot ScriptThis file instructs the compiled binary to request an IP and chainload our main menu.cat << 'EOF' > arranque_automatico.ipxe
#!ipxe
echo [!] Arsenal W.A.N. - Requesting DHCP & Locating Master Node...
dhcp
chain [http://pxeboot.1-s.eu/menu.ipxe](http://pxeboot.1-s.eu/menu.ipxe) || shell
EOF
1.4 Compile BIOS and UEFI BinariesThe make command will generate the required files inside newly created bin/ and bin-x86_64-efi/ directories within the ipxe/src/ folder.# Compile Payload 1: BIOS Legacy (Generates bin/ipxe.lkrn)
make bin/ipxe.lkrn EMBED=arranque_automatico.ipxe

# Compile Payload 2: UEFI 64-bit (Generates bin-x86_64-efi/ipxe.efi)
make bin-x86_64-efi/ipxe.efi EMBED=arranque_automatico.ipxe
Phase 2: Format and Partition the USB DriveCRITICAL WARNING: Ensure you identify the correct USB drive using lsblk. Running parted or mkfs on the wrong drive (/dev/sda etc.) will result in catastrophic data loss.2.1 Identify and Wipe DriveReplace /dev/sdX with your actual USB device identifier (e.g., /dev/sdc).USB_DRIVE="/dev/sdX"

# Create a clean Master Boot Record (MBR/msdos)
parted -s $USB_DRIVE mklabel msdos

# Create a single FAT32 partition utilizing 100% of the drive
parted -s -a optimal $USB_DRIVE mkpart primary fat32 1MiB 100%

# Mark the partition as bootable (Active flag)
parted -s $USB_DRIVE set 1 boot on
2.2 Format Partition# Format the newly created partition (Note the '1' appended to the drive path)
mkfs.vfat -F 32 -n "ARSENAL_PXE" ${USB_DRIVE}1
Phase 3: Install GRUB2 Bridge and PayloadsWe install GRUB twice on the same drive: once in the MBR for legacy BIOS, and once in the FAT32 filesystem for UEFI.3.1 Install GRUB Packagesapt install -y grub-pc-bin grub-efi-amd64-bin
3.2 Mount and Install Bootloadersmkdir -p /mnt/usb
mount ${USB_DRIVE}1 /mnt/usb

# Install GRUB for BIOS (Writes to MBR of /dev/sdX)
grub-install --target=i386-pc --boot-directory=/mnt/usb/boot --recheck $USB_DRIVE

# Install GRUB for UEFI (Writes to /mnt/usb/EFI/BOOT as removable media)
grub-install --target=x86_64-efi --efi-directory=/mnt/usb --boot-directory=/mnt/usb/boot --removable --recheck
3.3 Transfer Compiled iPXE PayloadsCopy the custom binaries compiled in Phase 1 to the USB drive.(Assuming you are still in the ipxe/src/ directory)mkdir -p /mnt/usb/boot/ipxe
cp bin/ipxe.lkrn /mnt/usb/boot/ipxe/
cp bin-x86_64-efi/ipxe.efi /mnt/usb/boot/ipxe/
3.4 Create GRUB Bridge ConfigurationThis script acts as the intelligence layer. It detects the firmware environment and executes the corresponding native iPXE payload.cat << 'EOF' > /mnt/usb/boot/grub/grub.cfg
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
EOF. The Master USB Key is now ready for deployment across all x86 architecture targets.


