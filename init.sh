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

echo "installing node_exporter from github"
wget -O /tmp/ne.tar.gz $(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep "browser_download_url" | grep "linux-amd64.tar.gz" | cut -d '"' -f 4 | head -n 1)

tar xf /tmp/ne.tar.gz -C /tmp
mv /tmp/node_exporter-*/node_exporter /usr/local/bin/
rm -rf /tmp/ne.tar.gz /tmp/node_exporter-*

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