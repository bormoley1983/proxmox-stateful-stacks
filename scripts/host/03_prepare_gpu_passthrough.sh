#!/usr/bin/env bash
set -euo pipefail

# Proxmox Host: GPU Passthrough Preparation Script
# This script helps prepare the Proxmox host for GPU passthrough
# Run this on the Proxmox HOST (not in a VM)

echo "[*] Proxmox GPU Passthrough Preparation"
echo "[!] This script should be run on the Proxmox HOST"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "[!] This script must be run as root (use sudo)"
   exit 1
fi

# Check if we're on Proxmox
if [[ ! -f /etc/pve/version ]]; then
    echo "[!] This script should be run on a Proxmox host"
    echo "[!] /etc/pve/version not found"
    exit 1
fi

echo "[*] Detected Proxmox version: $(cat /etc/pve/version)"

# Step 1: Check IOMMU status
echo ""
echo "[*] Checking IOMMU status..."
if grep -q "intel_iommu=on\|amd_iommu=on" /proc/cmdline; then
    echo "[✓] IOMMU is enabled in kernel"
else
    echo "[!] WARNING: IOMMU not found in kernel parameters"
    echo "[!] You need to enable IOMMU in GRUB:"
    echo ""
    echo "    For Intel: Add 'intel_iommu=on' to GRUB_CMDLINE_LINUX_DEFAULT"
    echo "    For AMD: Add 'amd_iommu=on' to GRUB_CMDLINE_LINUX_DEFAULT"
    echo ""
    echo "    Edit /etc/default/grub, then run:"
    echo "    update-grub && reboot"
    exit 1
fi

# Step 2: List GPUs
echo ""
echo "[*] Available GPUs:"
lspci | grep -iE "vga|3d|display" | grep -iE "nvidia|amd|intel" || echo "  No GPUs found"

# Step 3: Check for NVIDIA GPUs specifically
echo ""
echo "[*] NVIDIA GPUs:"
NVIDIA_GPUS=$(lspci | grep -i nvidia)
if [[ -n "$NVIDIA_GPUS" ]]; then
    echo "$NVIDIA_GPUS"
    echo ""
    echo "[*] GPU PCI IDs:"
    lspci | grep -i nvidia | awk '{print $1}' | while read -r pci_id; do
        echo "  $pci_id"
    done
else
    echo "  No NVIDIA GPUs found"
fi

# Step 4: Check if GPU is bound to vfio-pci
echo ""
echo "[*] Checking GPU driver binding..."
if command -v lspci &> /dev/null; then
    GPU_PCI=$(lspci | grep -i nvidia | head -1 | awk '{print $1}' | sed 's/:/\\:/g')
    if [[ -n "$GPU_PCI" ]]; then
        DRIVER=$(lspci -k -s "$GPU_PCI" 2>/dev/null | grep -i "kernel driver" | awk '{print $NF}' || echo "none")
        echo "  GPU at $GPU_PCI is using driver: $DRIVER"
        
        if [[ "$DRIVER" == "vfio-pci" ]]; then
            echo "[✓] GPU is already bound to vfio-pci (ready for passthrough)"
        else
            echo "[!] GPU is using driver: $DRIVER"
            echo "[!] To bind GPU to vfio-pci for passthrough:"
            echo ""
            echo "    1. Find GPU PCI ID:"
            echo "       lspci | grep -i nvidia"
            echo ""
            echo "    2. Add to /etc/modprobe.d/vfio.conf:"
            echo "       options vfio-pci ids=10de:XXXX,10de:YYYY"
            echo "       (replace XXXX/YYYY with your GPU device IDs)"
            echo ""
            echo "    3. Add to /etc/modules-load.d/vfio.conf:"
            echo "       vfio"
            echo "       vfio_iommu_type1"
            echo "       vfio_pci"
            echo "       vfio_virqfd"
            echo ""
            echo "    4. Update initramfs and reboot:"
            echo "       update-initramfs -u"
            echo "       reboot"
        fi
    fi
fi

# Step 5: Check for NVIDIA drivers on host
echo ""
echo "[*] Checking for NVIDIA drivers on host..."
if command -v nvidia-smi &> /dev/null; then
    echo "[!] WARNING: NVIDIA drivers are installed on the Proxmox host"
    echo "[!] For GPU passthrough, you should NOT have NVIDIA drivers on the host"
    echo "[!] The GPU should be bound to vfio-pci instead"
    echo ""
    echo "    To remove NVIDIA drivers:"
    echo "    apt remove --purge '^nvidia-.*'"
    echo "    apt autoremove"
else
    echo "[✓] No NVIDIA drivers found on host (correct for passthrough)"
fi

# Step 6: Check IOMMU groups
echo ""
echo "[*] IOMMU Groups (for reference):"
if [[ -d /sys/kernel/iommu_groups ]]; then
    echo "  IOMMU groups found. Checking GPU group..."
    GPU_PCI_ID=$(lspci | grep -i nvidia | head -1 | awk '{print $1}')
    if [[ -n "$GPU_PCI_ID" ]]; then
        # Convert PCI ID format (e.g., 01:00.0 -> 0000:01:00.0)
        PCI_ID_FORMATTED=$(echo "$GPU_PCI_ID" | sed 's/^/0000:/')
        for group in /sys/kernel/iommu_groups/*; do
            if [[ -L "$group/devices/$PCI_ID_FORMATTED" ]]; then
                GROUP_NUM=$(basename "$group")
                echo "  GPU $GPU_PCI_ID is in IOMMU group $GROUP_NUM"
                echo "  Devices in same group:"
                ls -1 "$group/devices/" | sed 's/^/    /'
                break
            fi
        done
    fi
else
    echo "  IOMMU groups directory not found"
fi

# Step 7: VM configuration reminder
echo ""
echo "[*] VM Configuration Reminder:"
echo "    When creating the VM in Proxmox:"
echo ""
echo "    1. Machine: q35"
echo "    2. BIOS: OVMF (UEFI)"
echo "    3. Add GPU passthrough:"
echo "       Hardware → Add → PCI Device"
echo "       Select your GPU"
echo "       Check 'All Functions' and 'ROM-Bar'"
echo "       ID format: 0000:XX:YY.Z"
echo ""
echo "    4. Or add manually to VM config:"
echo "       hostpci0: 0000:XX:YY.Z,pcie=1,rombar=0"
echo ""

echo "[✓] GPU passthrough preparation check complete"
echo ""
echo "[*] Next steps:"
echo "    1. Ensure IOMMU is enabled (if not, edit GRUB and reboot)"
echo "    2. Bind GPU to vfio-pci (if not already done)"
echo "    3. Create VM with GPU passthrough"
echo "    4. Install OS in VM"
echo "    5. Install NVIDIA drivers INSIDE the VM"
echo ""

