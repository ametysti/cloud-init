# cloud-init
## personal init script for servers

## features
- tailscale installation
- node_exporter that listens on the tailscale interface only. for monitoring the server
- iptables rules for allowing cloudflare and bunny.net traffic. configure port access in cdn-whitelist.sh as you should not open every port to a cdn provider.
- sets hourly cronjob for the cdn whitelist.


## tested working on
- debian 13 (hetzner using cloud-init)
- debian 12 (hetzner using cloud-init)
- debian 11 (hetzner using cloud-init)


## cloud-init config for providers
Copy the contents from [cloud-init.yaml](./cloud-init.yaml) file, and paste it to the cloud-init box where the hosting provider asks it.
If you use Tailscale, remember to set TS_AUTH_KEY in the cloud-init.yaml file.