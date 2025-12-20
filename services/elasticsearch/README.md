# Elasticsearch (VM recommended)

Run `setup.sh` **inside the container** for this service.

Template script for Debian VM; tune heap + vm.max_map_count.

If the service fails due to permissions on the bind-mounted data folder (unprivileged LXC),
run on the Proxmox host:

```bash
sudo bash scripts/host/02_fix_owner.sh inventory/homelab.env elasticsearch
```
