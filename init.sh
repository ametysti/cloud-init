#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION_CODENAME=${VERSION_CODENAME:-$(lsb_release -cs)}
else
    echo "Cannot detect OS. /etc/os-release missing."
    exit 1
fi

if ! command -v tailscale >/dev/null 2>&1; then
  echo "installing tailscale"

  if [[ "$TS_AUTH_KEY" != tskey-auth* ]]; then
    echo "TS_AUTH_KEY is missing or invalid. must start with 'tskey-auth'"
    exit 1
  fi

  curl -fsSL https://tailscale.com/install.sh | sh

  tailscale up --authkey="${TS_AUTH_KEY}" --ssh
  echo "tailscale installed"

else
  systemctl start tailscaled 2>/dev/null || true

  if ! tailscale ip -4 >/dev/null 2>&1; then
    echo "tailscale installed but not connected. bringing it online"
    tailscale up --ssh
  else
    echo "tailscale already connected. skipping tailscale up"
  fi
fi

VER=$(curl -fsSL https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep '"tag_name"' | cut -d '"' -f4 | sed 's/^v//')
ARCH=$([[ $(uname -m) == "x86_64" ]] && echo "amd64" || echo "arm64")
curl -sSL "https://github.com/prometheus/node_exporter/releases/download/v${VER}/node_exporter-${VER}.linux-${ARCH}.tar.gz" -o /tmp/node_exporter.tar.gz

tar -xzf /tmp/node_exporter.tar.gz -C /tmp
mv /tmp/node_exporter-${VER}.linux-${ARCH}/node_exporter /usr/local/bin/
rm -rf /tmp/node_exporter*

echo "adding systemd service for node_exporter"
cat <<EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network-online.target

[Service]
User=nobody
ExecStart=/usr/local/bin/node_exporter --web.listen-address=0.0.0.0:9100
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

curl -fsSL https://packagecloud.io/install/repositories/varnishcache/varnish80/script.deb.sh | bash

mkdir -p /etc/apt/keyrings
curl -fsSL https://haproxy.debian.net/haproxy-archive-keyring.gpg \
    -o /etc/apt/keyrings/haproxy.gpg

echo "deb [signed-by=/etc/apt/keyrings/haproxy.gpg] http://haproxy.debian.net ${VERSION_CODENAME}-backports-3.3 main" \
    > /etc/apt/sources.list.d/haproxy.list

apt-get update
apt-get install -y haproxy varnish

mkdir -p /var/lib/haproxy
chown varnish:haproxy /var/lib/haproxy
chmod 750 /var/lib/haproxy

mkdir -p /etc/systemd/system/varnish.service.d
cat <<EOF > /etc/systemd/system/varnish.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/sbin/varnishd \
  -a :6081 \
  -a /var/lib/haproxy/varnish.sock,proxy,user=varnish,group=haproxy,mode=660 \
  -f /etc/varnish/default.vcl \
  -s malloc,256m
LimitNOFILE=131072
LimitMEMLOCK=82000
EOF

systemctl daemon-reload
systemctl enable node_exporter varnish haproxy
systemctl restart varnish haproxy node_exporter

echo "done"