# Kafka

Run `setup.sh` **inside the container** for this service.

Data dir is expected at `/var/lib/kafka` (bind-mounted).

If the service fails due to permissions on the bind-mounted data folder (unprivileged LXC),
run on the Proxmox host:

```bash
sudo bash scripts/host/02_fix_owner.sh inventory/homelab.env kafka
```
