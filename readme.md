# cloud-init
personal init script for servers

## features
- barebones haproxy & varnish installation
- tailscale installation
- node_exporter. for monitoring the server
- nftables tables to allow CDN (port 443) and Tailscale ingress only. CDN IPs updated hourly.


## distro
cloud-init is intended and supported to work only on the latest Debian version and/or its predecessor:
- debian 13
- debian 12


## cloud-init config for providers
Copy the contents from [cloud-init.yaml](./cloud-init.yaml) file, and paste it to the cloud-init box where the hosting provider asks it.