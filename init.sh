#!/bin/bash

if ! command -v tailscale >/dev/null 2>&1; then
  echo "installing tailscale"

  if [[ "$TS_AUTH_KEY" != tskey-auth* ]]; then
    echo "TS_AUTH_KEY is missing or invalid. must start with 'tskey-auth'"
    exit 1
  fi

  curl -fsSL https://tailscale.com/install.sh | sh

  tailscale up --authkey="${TS_AUTH_KEY}" --ssh --advertise-exit-node
  echo "tailscale installed"

else
  systemctl start tailscaled 2>/dev/null || true

  if ! tailscale ip -4 >/dev/null 2>&1; then
    echo "tailscale installed but not logged in. bringing it online"
    tailscale up --ssh --advertise-exit-node
  else
    echo "tailscale already connected. skipping tailscale up"
  fi
fi

until [ ! -z "$TS_IP" ]; do
  TS_IP=$(tailscale ip -4)
  sleep 1
done

echo "installing node_exporter from sourceforge (mirror from github)"
SF_URL="https://sourceforge.net/projects/node-exporter.mirror/files/"

VER=$(wget -qO- "$SF_URL" \
  | grep -oP 'href="/projects/node-exporter\.mirror/files/v[0-9]+\.[0-9]+\.[0-9]+/"' \
  | sed -E 's|href="/projects/node-exporter\.mirror/files/||; s|/||; s|"||g' \
  | sort -V | tail -n1)

if [[ -z "$VER" ]]; then
    echo "Failed to detect latest version for node_exporter!"
    exit 1
fi

TARBALL_URL="${SF_URL}${VER}/node_exporter-${VER#v}.linux-amd64.tar.gz/download"

echo "latest node_exporter version: $VER"

wget -O /tmp/ne.tar.gz "$TARBALL_URL"
tar -xzf /tmp/ne.tar.gz -C /tmp
mv /tmp/node_exporter-*/node_exporter /usr/local/bin/
rm -rf /tmp/ne.tar.gz /tmp/node_exporter-*/

echo "adding systemd service for node_exporter"
cat <<EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network-online.target tailscaled.service

[Service]
User=nobody
ExecStart=/usr/local/bin/node_exporter --web.listen-address=${TS_IP}:9100

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now node_exporter

echo "done"