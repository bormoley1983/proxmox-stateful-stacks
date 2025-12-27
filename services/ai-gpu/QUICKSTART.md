# AI GPU VM - Quick Start Guide

Quick reference for setting up and using the AI GPU VM.

## Prerequisites Checklist

- [ ] Proxmox host with GPU
- [ ] BIOS: IOMMU enabled, Above 4G decoding enabled
- [ ] GPU bound to `vfio-pci` on host (no NVIDIA drivers on host)
- [ ] VM created with GPU passthrough (q35, OVMF, hostpci0 configured)

## Setup Steps

### 1. Host Preparation (Proxmox Host)

```bash
sudo bash scripts/host/03_prepare_gpu_passthrough.sh
```

### 2. VM Setup (Inside VM)

```bash
# Clone or copy the setup script to the VM
sudo bash services/ai-gpu/setup.sh

# Reboot if NVIDIA drivers were installed
sudo reboot
```

### 3. Verify GPU (After Reboot)

```bash
nvidia-smi
watch -n 1 nvidia-smi  # Continuous monitoring
```

### 4. Start Services

```bash
cd /opt/ai-gpu
docker compose up -d
```

### 5. Access Services

- **OpenWebUI**: http://VM_IP:3000
- **Ollama API**: http://VM_IP:11434
- **vLLM API**: http://VM_IP:8000/v1

## Common Commands

### Service Management

```bash
# Start all services
cd /opt/ai-gpu && docker compose up -d

# Stop all services
docker compose down

# View logs
docker compose logs -f
docker logs -f ollama
docker logs -f vllm
docker logs -f openwebui

# Restart a service
docker compose restart ollama
```

### Ollama Operations

```bash
# Pull models
docker exec -it ollama ollama pull llama3.1
docker exec -it ollama ollama pull gpt-oss:20b

# List models
docker exec -it ollama ollama list

# Run a model
docker exec -it ollama ollama run llama3.1

# Test API
curl http://localhost:11434/api/tags
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.1",
  "prompt": "Hello"
}'
```

### vLLM Operations

```bash
# Check API
curl http://localhost:8000/v1/models

# Test completion
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "microsoft/Phi-3-mini-4k-instruct",
    "prompt": "Hello",
    "max_tokens": 50
  }'
```

### Monitoring

```bash
# GPU status
nvidia-smi
watch -n 1 nvidia-smi

# Container status
docker ps
docker stats

# Disk usage
df -h
du -sh /models/*
```

## Troubleshooting

### GPU Not Visible

```bash
# Check GPU in VM
lspci | grep -i nvidia
nvidia-smi

# Check Docker GPU access
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
```

### Services Won't Start

```bash
# Check logs
docker compose logs

# Check ports
sudo netstat -tulpn | grep -E '3000|8000|11434'

# Check disk space
df -h
```

### Container Can't Access GPU

```bash
# Verify NVIDIA Container Toolkit
docker info | grep -i nvidia

# Restart Docker
sudo systemctl restart docker
```

## VM Configuration Reference

Key VM settings:
- **Machine**: q35
- **BIOS**: OVMF (UEFI)
- **CPU**: host, 16 cores
- **Memory**: 40 GB
- **GPU**: `hostpci0: 0000:01:00,pcie=1`
- **Storage**: 500GB (OS) + 400GB (models)

Full config example in `README.md`.

## Next Steps

- Pull more models for Ollama
- Configure OpenWebUI settings
- Set up GPU stress testing (gpu-burn)
- Benchmark performance (ollama-bench)
- Add Whisper STT or YOLO CV pipelines

