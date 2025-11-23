#!/bin/bash
set -euo pipefail

# config
CF_URL="https://www.cloudflare.com/ips-v4"
BUNNY_URL="https://bunnycdn.com/api/system/edgeserverlist/plain"
# config end

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# ports that these providers could access then
PORT_CF=(80 443)
PORT_BUNNY=(80 443 2096 8055)

CF_FILE="$TMP_DIR/cloudflare_ips"
BUNNY_FILE="$TMP_DIR/bunny_ips"

update_ipset() {
    local set_name="$1"
    local file="$2"
    local tmp_set_name="${set_name}_tmp"

    local line_count
    line_count=$(grep -c . "$file" || true)

    if [[ "$line_count" -lt 5 ]]; then
        echo "error: $set_name list looks broken (too few lines). Aborting."
        return 1
    fi

    ipset destroy "$tmp_set_name" 2>/dev/null || true
    ipset create "$tmp_set_name" hash:net

    echo "rebuilding set: $set_name..."
    while read -r ip; do
        [[ -n "$ip" ]] && ipset add "$tmp_set_name" "$ip" -exist
    done < "$file"

    ipset list "$set_name" >/dev/null 2>&1 || ipset create "$set_name" hash:net

    echo "swapping $set_name -> live"
    ipset swap "$tmp_set_name" "$set_name"
    ipset destroy "$tmp_set_name"
}

ensure_iptables_rule() {
    local target_set="$1"
    local ports="$2"
    
    if ! iptables -C INPUT -p tcp -m multiport --dports "$ports" -m set --match-set "$target_set" src -j ACCEPT 2>/dev/null; then
        echo "adding allow rule: $target_set"
        iptables -I INPUT 1 -p tcp -m multiport --dports "$ports" -m set --match-set "$target_set" src -j ACCEPT
    fi
}

ensure_drop_rule() {
    local port="$1"
    if ! iptables -C INPUT -p tcp --dport "$port" -j DROP 2>/dev/null; then
        echo "locking down port $port (DROP)"
        iptables -A INPUT -p tcp --dport "$port" -j DROP
    fi
}

echo "downloading lists..."

if ! curl -s --retry 3 --max-time 10 "$CF_URL" -o "$CF_FILE"; then
    echo "failed to get Cloudflare IPs."
    exit 1
fi

if ! curl -s --retry 3 --max-time 10 "$BUNNY_URL" -o "$BUNNY_FILE"; then
    echo "failed to get bunny.net IPs."
    exit 1
fi

sed -i 's/\r//' "$CF_FILE" "$BUNNY_FILE"
grep -Eo '^[0-9]{1,3}(\.[0-9]{1,3}){3}(/[0-9]{1,2})?$' "$CF_FILE" > "$CF_FILE.clean"
grep -Eo '^[0-9]{1,3}(\.[0-9]{1,3}){3}(/[0-9]{1,2})?$' "$BUNNY_FILE" > "$BUNNY_FILE.clean"

update_ipset "cloudflare" "$CF_FILE.clean"
update_ipset "bunny" "$BUNNY_FILE.clean"

CF_PORTS_CSV=$(IFS=,; echo "${PORT_CF[*]}")
BUNNY_PORTS_CSV=$(IFS=,; echo "${PORT_BUNNY[*]}")

ensure_iptables_rule "cloudflare" "$CF_PORTS_CSV"
ensure_iptables_rule "bunny" "$BUNNY_PORTS_CSV"

for port in "${PORT_CF[@]}" "${PORT_BUNNY[@]}"; do
    ensure_drop_rule "$port"
done

echo "done"