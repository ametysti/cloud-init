# cloud-init
personal init script for servers

## GitHub users
This repo is mirrored to GitHub from the [GitLab repository](https://gitlab.com/ametysti/cloud-init).
Reasoning behind this is because GitHub still in the big 2020s [does not support ipv6](https://ready.chair6.net/?url=https%3A%2F%2Fapi.github.com). 

For my ipv6-only servers this is a problem, so no links in the files use GitHub anymore. gitlab better anyway :p

## features
- tailscale installation
- node_exporter that listens on the tailscale interface only. for monitoring the server
- iptables rules for allowing cloudflare and bunny.net traffic. configure port access in cdn-whitelist.sh as you should not open every port to a cdn provider.
- sets hourly cronjob for the cdn whitelist.


## tested working on
all tested on hetzner cloud servers using cloud-init
- debian 13
- debian 12
- debian 11
- ubuntu 24.04
- ubuntu 22.04


## cloud-init config for providers
Copy the contents from [cloud-init.yaml](./cloud-init.yaml) file, and paste it to the cloud-init box where the hosting provider asks it.
If you use Tailscale, remember to set TS_AUTH_KEY in the cloud-init.yaml file.