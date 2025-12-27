# n8n

Run `setup.sh` **inside the container** for this service.

n8n requires:
- PostgreSQL (existing service)
- Redis (existing service)

Data dirs are expected at `/var/lib/n8n` (bind-mounted) with subdirectories:
- `n8n_data` - main n8n data
- `files` - file storage
- `backups` - backup storage
- `caddy_config` - Caddy configuration
- `caddy` - Caddy data

If the service fails due to permissions on the bind-mounted data folder (unprivileged LXC),
run on the Proxmox host:

```bash
sudo bash scripts/host/02_fix_owner.sh inventory/homelab.env n8n
```

## Prerequisites

Before running the n8n setup, ensure:

1. **PostgreSQL** is set up and running
2. **Redis** is set up and running
3. **LXC container** has nesting enabled: `features: nesting=1,keyctl=1` in `/etc/pve/lxc/<CTID>.conf`
4. **Database and user** are created in PostgreSQL (see below)
5. **Redis ACL user** is created (see below)

### Setting up PostgreSQL

On the PostgreSQL container, run:

```bash
# Set environment variables (or edit the script)
export DB_POSTGRESDB_DATABASE=n8n
export DB_POSTGRESDB_USER=n8n
export DB_POSTGRESDB_PASSWORD=your_secure_password

# Run the helper script
sudo -u postgres bash services/n8n/setup-postgres.sh
```

Or manually run the SQL commands shown in the setup script output.

### Setting up Redis

On the Redis container or from host with redis-cli access:

```bash
# Set environment variables
export REDIS_ADMIN_PASS=your_redis_admin_password
export QUEUE_BULL_REDIS_USERNAME=n8n
export QUEUE_BULL_REDIS_PASSWORD=your_secure_password
export QUEUE_BULL_REDIS_HOST=redis.homelab.local
export QUEUE_BULL_REDIS_PORT=6379

# Run the helper script
bash services/n8n/setup-redis.sh
```

## Configuration

The setup script will:
1. Install Docker and Docker Compose
2. Create the n8n user and add to docker group
3. Set up environment variables
4. Configure Docker Compose with n8n-main, n8n-worker, and Caddy
5. Generate encryption key

Edit `/opt/n8n/.env` after setup to configure:
- Database credentials
- Redis credentials
- Hostname and protocol
- Timezone

## Docker Compose Services

- **n8n-main**: Main n8n process (web UI and API)
- **n8n-worker**: Worker process for queue mode
- **caddy**: Reverse proxy with TLS

## Queue Mode

n8n is configured to run in queue mode using Redis, which allows:
- Better scalability
- Separation of main process and workers
- Manual executions can be offloaded to workers

