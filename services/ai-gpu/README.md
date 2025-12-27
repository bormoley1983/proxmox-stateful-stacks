# AI GPU VM (Proxmox with GPU Passthrough)

Dedicated AI/inference VM on Proxmox with full GPU passthrough for LLM inference, OpenAI-compatible APIs, and unified web UI.

## Purpose & Design Goals

- **Node role**: Dedicated AI / inference VM on Proxmox
- **Single GPU**: Full device passthrough (no MIG, no multi-GPU)
- **Mixed workloads**:
  - LLM inference (Ollama, vLLM, llama.cpp-ready)
  - OpenAI-compatible APIs
  - Web UI (OpenWebUI)
  - GPU stress & benchmarking
  - Future CV / YOLO / Whisper STT

**Key principles**:
- GPU passthrough (full device)
- Host stays minimal and stable
- All AI stack runs inside VM via Docker
- Reproducible, documented, automatable

## Prerequisites

### Proxmox Host Preparation

#### BIOS Settings
- **SVM**: Enabled
- **IOMMU**: Enabled
- **Above 4G decoding**: Enabled
- **PCIe speed**: GEN4 (forced)
- **CSM**: Disabled
- **Resizable BAR**: Optional (safe to leave enabled)

#### Proxmox Host Kernel
- IOMMU enabled (already working if passthrough works)
- GPU bound to `vfio-pci`
- **No NVIDIA drivers installed on host**

Run the host preparation script:
```bash
sudo bash scripts/host/03_prepare_gpu_passthrough.sh
```

### VM Configuration (Proxmox)

Create a VM with the following settings:

**VM Identity**:
- **Name**: `ai-gpu`
- **OS Type**: Linux 6.x - 2.6 Kernel
- **Machine**: `q35`
- **BIOS**: `OVMF (UEFI)`

**CPU & Memory**:
- **Sockets**: 1
- **Cores**: 16
- **CPU type**: `host`
- **NUMA**: disabled
- **Memory**: 40 GB (ballooning OFF)

**Storage**:
- **SCSI Controller**: VirtIO SCSI single
  - `scsi0`: 500G (OS / containers)
  - `scsi1`: 400G (models / datasets)
- **Discard**: on
- **IOThread**: enabled
- **SSD emulation**: enabled

**EFI**:
- **EFI Disk**: 4M
- **Secure Boot**: enabled
- **MS certs**: 2023

**GPU Passthrough**:
- `hostpci0: 0000:01:00,pcie=1` (full GPU, no audio split)

**Networking**:
- `net0`: virtio
- `bridge`: vmbr0
- `firewall`: enabled

**Misc**:
- **QEMU Guest Agent**: enabled
- **On boot**: yes
- **ACPI**: yes
- **KVM HW virtualization**: yes

**Example VM config** (from `/etc/pve/qemu-server/050.conf`):
```
agent: 1
balloon: 0
bios: ovmf
boot: order=scsi0
cores: 16
cpu: host
efidisk0: lvm-thin:vm-050-disk-0,efitype=4m,ms-cert=2023,pre-enrolled-keys=1,size=4M
hostpci0: 0000:01:00,pcie=1
ide2: none,media=cdrom
machine: q35
memory: 40960
name: ai-gpu
net0: virtio=BC:24:11:aa:bb:cc,bridge=vmbr0,firewall=1
numa: 0
onboot: 1
ostype: l26
scsi0: lvm-thin:vm-050-disk-1,backup=0,discard=on,iothread=1,replicate=0,size=500G,ssd=1
scsi1: lvm-thin:vm-050-disk-2,backup=0,discard=on,iothread=1,replicate=0,size=400G,ssd=1
scsihw: virtio-scsi-single
sockets: 1
```

## Installation

### 1. Inside the VM - Base OS Setup

Install Debian/Ubuntu and run the setup script:

```bash
sudo bash services/ai-gpu/setup.sh
```

This will:
1. Install Docker and Docker Compose
2. Install NVIDIA drivers
3. Install NVIDIA Container Toolkit
4. Verify GPU visibility
5. Set up directory structure
6. Configure Docker Compose services

### 2. Verify GPU Access

After setup, verify GPU is accessible:

```bash
watch -n 1 nvidia-smi
```

You should see your GPU (e.g., RTX 3090) with proper driver version.

### 3. Start Services

Start all services with Docker Compose:

```bash
cd /opt/ai-gpu
docker compose up -d
```

Or start individual services:

```bash
# Start Ollama
docker compose up -d ollama

# Start vLLM
docker compose up -d vllm

# Start OpenWebUI
docker compose up -d openwebui
```

## Services

### Ollama (GPU Inference)

**Port**: `11434`

**Usage**:
```bash
# Pull models
docker exec -it ollama ollama pull llama3.1
docker exec -it ollama ollama pull gpt-oss:20b

# Run models
docker exec -it ollama ollama run llama3.1
docker exec -it ollama ollama run gpt-oss:20b --verbose
```

**API**:
```bash
# List models
curl http://localhost:11434/api/tags

# Generate text
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.1",
  "prompt": "Say hello from the GPU VM"
}'
```

**Data**: Models stored in Docker volume `ollama-data` (mapped to `/models/ollama`)

### vLLM (OpenAI-compatible API)

**Port**: `8000`

**Default model**: `microsoft/Phi-3-mini-4k-instruct`

**Configuration**:
- GPU memory utilization: 90%
- Max model length: 4096
- Host: 0.0.0.0 (accessible from network)

**Usage**:
```bash
# Check logs
docker logs -f vllm

# Test API
curl http://localhost:8000/v1/models
```

**OpenAI-compatible endpoint**: `http://VM_IP:8000/v1`

### OpenWebUI (Unified UI)

**Port**: `3000`

**Access**: `http://VM_IP:3000`

**Features**:
- Unified interface for Ollama and vLLM
- Model management
- Chat interface
- API key management

**Configuration**:
- Backend: vLLM (OpenAI-compatible) at `http://vllm:8000/v1`
- Ollama backend: `http://ollama:11434`
- Data persisted in `./data` directory

## Monitoring & Operations

### GPU Monitoring
```bash
# Continuous monitoring
watch -n 1 nvidia-smi

# One-time check
nvidia-smi
```

### Container Management
```bash
# List containers
docker ps

# View logs
docker logs -f ollama
docker logs -f vllm
docker logs -f openwebui

# Restart services
docker compose restart ollama
docker compose restart vllm
docker compose restart openwebui

# Stop all services
docker compose down

# Start all services
docker compose up -d
```

## Directory Structure

```
/opt/ai-gpu/
├── docker-compose.yml    # Main compose file
├── .env                  # Environment variables (optional)
└── data/                 # OpenWebUI data
    └── ...

/models/                  # Model storage
├── ollama/              # Ollama models (bind mount)
└── ...
```

## GPU Stress Testing & Benchmarking

### gpu-burn

Located in `/opt/gpu-burn/` (if installed separately).

Used to:
- Validate thermals
- Confirm no PCIe / passthrough instability
- Verify sustained power draw

### ollama-bench

Located in `/opt/ollama-bench/` (if installed separately).

Purpose:
- Power vs performance curves
- Compare undervolt / TDP caps
- Compare future GPUs

## Troubleshooting

### GPU Not Visible

1. Verify GPU passthrough on Proxmox host:
   ```bash
   # On Proxmox host
   lspci | grep -i nvidia
   ```

2. Check VM config has `hostpci0` entry

3. Verify NVIDIA drivers in VM:
   ```bash
   nvidia-smi
   ```

4. Check NVIDIA Container Toolkit:
   ```bash
   docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
   ```

### Containers Can't Access GPU

1. Verify NVIDIA Container Toolkit installation:
   ```bash
   docker info | grep -i nvidia
   ```

2. Check container has `--gpus all` or `deploy.resources.reservations.devices` in compose

3. Restart Docker daemon:
   ```bash
   sudo systemctl restart docker
   ```

### High GPU Temperatures

- Monitor with `nvidia-smi`
- Check case airflow
- Consider power limiting (PPT cap)
- Verify boost clocks are reasonable

### Services Not Starting

1. Check logs:
   ```bash
   docker compose logs
   ```

2. Verify ports are not in use:
   ```bash
   sudo netstat -tulpn | grep -E '3000|8000|11434'
   ```

3. Check disk space:
   ```bash
   df -h
   ```

## Performance Tuning

### vLLM Memory Utilization

Edit `docker-compose.yml` to adjust:
```yaml
environment:
  - VLLM_WORKER_GPU_MEMORY_UTILIZATION=0.9  # Adjust 0.7-0.95
```

### Ollama Model Loading

Larger models may require more shared memory:
```yaml
shm_size: 4g  # Increase if needed
```

### CPU Affinity (Optional)

For better performance, you can pin containers to specific CPUs:
```yaml
deploy:
  resources:
    reservations:
      cpus: '0-15'
```

## Next Steps (Optional Enhancements)

- [ ] PBO fine tuning
- [ ] PPT cap enforcement (manual PPT ≈ 90,000 mW)
- [ ] Curve Optimizer (negative, per-core if available)
- [ ] Whisper STT service (Faster-whisper / CTranslate2 container)
- [ ] GPU scheduling with Ollama
- [ ] YOLO / CV pipeline (RTSP ingest, CUDA-enabled OpenCV / Ultralytics)
- [ ] Automation (cloud-init template, Ansible role)
- [ ] docker-compose bundle for full stack

## References

- [Ollama Documentation](https://ollama.ai/docs)
- [vLLM Documentation](https://docs.vllm.ai/)
- [OpenWebUI Documentation](https://docs.openwebui.com/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)
- [Proxmox GPU Passthrough](https://pve.proxmox.com/wiki/PCI_Passthrough)

