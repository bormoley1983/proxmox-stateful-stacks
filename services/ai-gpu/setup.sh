#!/usr/bin/env bash
set -euo pipefail

echo "[*] AI GPU VM Setup Script"
echo "[*] This script sets up Docker, NVIDIA drivers, and AI inference stack"
echo ""

# Detect OS
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo "[!] Cannot detect OS. Exiting."
    exit 1
fi

echo "[*] Detected OS: $OS $VERSION"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "[!] This script must be run as root (use sudo)"
   exit 1
fi

# Step 1: Update system
echo "[*] Updating system packages..."
apt update
apt install -y ca-certificates curl gnupg lsb-release software-properties-common

# Step 2: Install Docker
echo "[*] Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm -f get-docker.sh
    echo "[✓] Docker installed"
else
    echo "[*] Docker already installed"
fi

# Step 3: Install Docker Compose
echo "[*] Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo "[✓] Docker Compose installed"
else
    echo "[*] Docker Compose already installed"
fi

# Step 4: Install NVIDIA drivers
echo "[*] Installing NVIDIA drivers..."
if ! command -v nvidia-smi &> /dev/null; then
    # Add NVIDIA package repositories
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    apt update
    apt install -y nvidia-driver-535 nvidia-utils-535
    echo "[✓] NVIDIA drivers installed"
    echo "[!] IMPORTANT: Reboot the VM after this script completes to load NVIDIA drivers"
else
    echo "[*] NVIDIA drivers already installed"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
fi

# Step 5: Install NVIDIA Container Toolkit
echo "[*] Installing NVIDIA Container Toolkit..."
if ! docker info 2>/dev/null | grep -q nvidia; then
    apt install -y nvidia-container-toolkit
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
    echo "[✓] NVIDIA Container Toolkit installed and configured"
else
    echo "[*] NVIDIA Container Toolkit already configured"
fi

# Step 6: Verify GPU access
echo "[*] Verifying GPU access..."
if command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        echo "[✓] GPU is accessible"
        nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
    else
        echo "[!] WARNING: nvidia-smi failed. GPU may not be properly passed through."
        echo "[!] Ensure GPU passthrough is configured in Proxmox VM settings."
    fi
else
    echo "[!] WARNING: nvidia-smi not found. Install NVIDIA drivers and reboot."
fi

# Step 7: Test Docker GPU access
echo "[*] Testing Docker GPU access..."
if docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi &> /dev/null; then
    echo "[✓] Docker can access GPU"
else
    echo "[!] WARNING: Docker GPU test failed. Check NVIDIA Container Toolkit installation."
fi

# Step 8: Create directory structure
echo "[*] Creating directory structure..."
mkdir -p /opt/ai-gpu/data
mkdir -p /models/ollama

# Step 9: Copy docker-compose.yml
echo "[*] Setting up Docker Compose configuration..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/docker-compose.yml" ]]; then
    cp "$SCRIPT_DIR/docker-compose.yml" /opt/ai-gpu/docker-compose.yml
    echo "[✓] Docker Compose file copied to /opt/ai-gpu/"
else
    echo "[!] WARNING: docker-compose.yml not found in $SCRIPT_DIR"
fi

# Step 10: Set permissions
echo "[*] Setting permissions..."
# Get the current user (if running with sudo)
if [[ -n "${SUDO_USER:-}" ]]; then
    chown -R "$SUDO_USER:$SUDO_USER" /opt/ai-gpu
    chown -R "$SUDO_USER:$SUDO_USER" /models
    echo "[✓] Permissions set for user: $SUDO_USER"
else
    echo "[!] Could not determine user for permissions"
fi

echo ""
echo "[✓] Setup complete!"
echo ""
echo "[*] Next steps:"
echo "    1. If NVIDIA drivers were just installed, REBOOT the VM:"
echo "       sudo reboot"
echo ""
echo "    2. After reboot, verify GPU:"
echo "       nvidia-smi"
echo ""
echo "    3. Start AI services:"
echo "       cd /opt/ai-gpu"
echo "       docker compose up -d"
echo ""
echo "    4. Check service status:"
echo "       docker compose ps"
echo "       docker compose logs -f"
echo ""
echo "    5. Access OpenWebUI:"
echo "       http://$(hostname -I | awk '{print $1}'):3000"
echo ""
echo "[*] Useful commands:"
echo "    # Monitor GPU"
echo "    watch -n 1 nvidia-smi"
echo ""
echo "    # Pull Ollama models"
echo "    docker exec -it ollama ollama pull llama3.1"
echo ""
echo "    # Check vLLM API"
echo "    curl http://localhost:8000/v1/models"
echo ""

