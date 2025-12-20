# Proxmox 9 Stateful Stacks (LXC + bind mounts)

Build on the basis of newley created homelab environment. if you have any issues - I'd love to help, just open a ticket or ping me directly

A shareable template for running common **stateful** services in **Proxmox LXC** while keeping **data on the Proxmox host** (ext4), so you can rebuild/replace containers without losing DB state.

- **Stateful data**: stored on the host under `/srv/storage/db/...` and bind-mounted into LXCs.
- **Stateless services**: run in Kubernetes (k3s) or temporary VMs/LXCs.
- **Microsoft stack excluded**: AD / MSSQL live on separate hosts.

> ⚠️ Security  
> This repo uses `CHANGEME` / example IPs/passwords.  
> Put real values only in `inventory/homelab.env` (gitignored).

## Folder layout

- `inventory/` – example env file
- `scripts/host/` – run on **Proxmox host**
- `scripts/ct/` – run **inside a container**
- `services/<service>/setup.sh` – run **inside that service container**

## Resource baseline (lightweight homelab)

| Service | vCPU | RAM | SWAP | Root disk |
|---|---:|---:|---:|---:|
| PostgreSQL | 2 | 4 GB | 512 MB | 8–12 GB |
| Redis | 1 | 1 GB | 256 MB | 4–6 GB |
| RabbitMQ | 1 | 2 GB | 512 MB | 6–8 GB |
| Kafka (later) | 2–4 | 6–8 GB | 1 GB | 8–12 GB |
| Qdrant | 2 | 4 GB | 512 MB | 6–8 GB |
| MongoDB | 2 | 4 GB | 512 MB | 8–12 GB |
| Elasticsearch (optional) | 2–4 | 8–16 GB | 1–2 GB | 12–20 GB |

## Quick start

### 0) Create your local inventory (sample generic setup commited)

```bash
cp inventory/homelab.example.env inventory/homelab.env
nano inventory/homelab.env
```

### 1) Prepare host storage (Proxmox host)

```bash
sudo bash scripts/host/00_prepare_storage.sh
```

### 2) Create LXCs (your preferred method)

Recommendation: Debian (bookworm/trixie) **unprivileged** LXC.

### 3) Bind-mount service data dirs (Proxmox host)

```bash
sudo bash scripts/host/01_bind_mounts.sh inventory/homelab.env
```

### 4) Fix ownership for unprivileged LXC (Proxmox host)

Run per service container:
```bash
sudo bash scripts/host/02_fix_owner.sh inventory/homelab.env postgresql
sudo bash scripts/host/02_fix_owner.sh inventory/homelab.env redis
sudo bash scripts/host/02_fix_owner.sh inventory/homelab.env rabbitmq
sudo bash scripts/host/02_fix_owner.sh inventory/homelab.env kafka
sudo bash scripts/host/02_fix_owner.sh inventory/homelab.env qdrant
sudo bash scripts/host/02_fix_owner.sh inventory/homelab.env mongodb
```

### 5) Bootstrap a sudo+ssh user (inside each CT)

```bash
sudo bash scripts/ct/00_bootstrap_user_ssh.sh
```

### 6) Install each service (inside the service CT)

```bash
sudo bash services/postgresql/setup.sh
sudo bash services/redis/setup.sh
sudo bash services/rabbitmq/setup.sh
sudo bash services/kafka/setup.sh
sudo bash services/qdrant/setup.sh
sudo bash services/mongodb/setup.sh
sudo bash services/elasticsearch/setup.sh
```

