personal init script for servers

### features
- tailscale installation
- node_exporter that listens on the tailscale interface only. for monitoring the server
- iptables rules for allowing cloudflare and bunny.net traffic. configure port access in cdn-whitelist.sh as you should not open every port to a cdn provider.


## cloud-init config for providers

```yaml
#include
https://raw.githubusercontent.com/ametysti/cloud-init/main/cloud-init.yaml
```