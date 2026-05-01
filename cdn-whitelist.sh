#!/bin/bash
set -euo pipefail

log() { echo "[cdn] $1"; }

CF_V4=$(curl -fsSL --retry 3 https://www.cloudflare.com/ips-v4)
CF_V6=$(curl -fsSL --retry 3 https://www.cloudflare.com/ips-v6)
#BUNNY_V4=$(curl -fsSL --retry 3 https://bunnycdn.com/api/system/edgeserverlist/plain)
#BUNNY_V6=$(curl -fsSL --retry 3 https://bunnycdn.com/api/system/edgeserverlist/IPv6/plain)

update_set () {
    local family="$1"
    local set="$2"
    local data="$3"

    log "updating $set ($family)"

    if [[ -z "$data" ]]; then
        log "ERROR: empty dataset for $set, skipping"
        return 1
    fi

    nft flush set inet filter "$set"

    while read -r ip; do
        [[ -n "$ip" ]] && nft add element inet filter "$set" { "$ip" }
    done <<< "$data"
}

update_set v4 cf_v4 "$CF_V4"
update_set v6 cf_v6 "$CF_V6"
#update_set v4 bunny_v4 "$BUNNY_V4"
#update_set v6 bunny_v6 "$BUNNY_V6"

log "update complete"