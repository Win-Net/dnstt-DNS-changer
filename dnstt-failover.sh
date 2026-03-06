#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer v1.9.0 - With Auto-Scan
# https://github.com/Win-Net/dnstt-DNS-changer
# ═══════════════════════════════════════════════════════════

CONFIG_FILE="/etc/dnstt-DNS-changer/config.conf"

if [ ! -f "$CONFIG_FILE" ]; then echo "[FATAL] No config"; exit 1; fi
source "$CONFIG_FILE"

[ ${#DNS_SERVERS[@]} -eq 0 ] && { echo "[FATAL] No servers"; exit 1; }
[ ${#DNS_SERVERS[@]} -ne ${#DOMAINS[@]} ] && { echo "[FATAL] Mismatch"; exit 1; }
[ ! -f "$BINARY" ] && { echo "[FATAL] No binary"; exit 1; }
[ ! -x "$BINARY" ] && chmod +x "$BINARY"
[ ! -f "$PUBKEY_FILE" ] && { echo "[FATAL] No key"; exit 1; }

IDX=0
TOTAL=${#DNS_SERVERS[@]}
TAG="dnstt-DNS-changer"
SWITCHES=0
DNSTT_PID=0
CHECK=${AUTO_RESTART_CHECK:-15}
FAILS=0
MAX_FAIL=${MAX_FAILURES:-2}
PORT="${LOCAL_LISTEN##*:}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2"
    logger -t "$TAG" "$1: $2" 2>/dev/null
}

nuke() {
    pkill -9 -f "dnstt-client" 2>/dev/null
    sleep 1
    if command -v fuser &>/dev/null; then
        fuser -k ${PORT}/tcp 2>/dev/null
    fi
    sleep 1
    local i=0
    while ss -tlnp 2>/dev/null | grep -q ":${PORT}" && [ $i -lt 10 ]; do
        sleep 1; i=$((i+1))
    done
    DNSTT_PID=0
}

start_dnstt() {
    local dns="${DNS_SERVERS[$IDX]}"
    local domain="${DOMAINS[$IDX]}"
    log "INFO" "========================================"
    log "INFO" "Starting [$((IDX+1))/$TOTAL] DNS=$dns Domain=$domain"
    log "INFO" "========================================"

    nuke
    sleep 2

    if [ "${PROTOCOL:-udp}" = "dot" ]; then
        $BINARY -dot "$dns" -pubkey-file "$PUBKEY_FILE" "$domain" "$LOCAL_LISTEN" &
    else
        $BINARY -udp "$dns" -pubkey-file "$PUBKEY_FILE" "$domain" "$LOCAL_LISTEN" &
    fi
    DNSTT_PID=$!
    sleep 5

    if ! kill -0 $DNSTT_PID 2>/dev/null; then
        log "ERROR" "Process died immediately"
        DNSTT_PID=0
        return 1
    fi
    log "INFO" "Running PID=$DNSTT_PID"
    return 0
}

is_alive() {
    if [ "$DNSTT_PID" -eq 0 ] 2>/dev/null || ! kill -0 $DNSTT_PID 2>/dev/null; then
        log "WARNING" "Process dead"
        return 1
    fi
    if ! ss -tlnp 2>/dev/null | grep -q ":${PORT}"; then
        log "WARNING" "Port $PORT closed"
        return 1
    fi
    if command -v curl &>/dev/null; then
        if timeout 10 curl -s --socks5 "$LOCAL_LISTEN" "http://cp.cloudflare.com" -o /dev/null 2>/dev/null; then
            return 0
        fi
        if timeout 10 curl -s --socks5 "$LOCAL_LISTEN" "http://www.gstatic.com/generate_204" -o /dev/null 2>/dev/null; then
            return 0
        fi
        log "WARNING" "SOCKS not responding"
        return 1
    fi
    return 0
}

next_dns() {
    local old="${DNS_SERVERS[$IDX]}"
    IDX=$(( (IDX + 1) % TOTAL ))
    SWITCHES=$((SWITCHES + 1))
    log "SWITCH" "$old -> ${DNS_SERVERS[$IDX]} (switch #$SWITCHES)"
}

# ═══ AUTO SCAN: Find new DNS servers ═══
auto_scan() {
    source "$CONFIG_FILE" 2>/dev/null
    local scan_on=${AUTO_SCAN_ENABLED:-false}
    [ "$scan_on" != "true" ] && return

    local scan_count=${AUTO_SCAN_COUNT:-30}
    local scan_domain=${AUTO_SCAN_DOMAIN:-}
    local scan_port=${AUTO_SCAN_PORT:-53}

    [ -z "$scan_domain" ] && return

    if ! command -v dig &>/dev/null; then
        log "WARNING" "dig not installed, cannot auto-scan"
        return
    fi

    log "INFO" "AUTO-SCAN: Starting scan for $scan_count DNS servers"

    local RANGES=(
        "1.0" "1.1" "4.2" "5.2" "8.8" "8.26" "9.9" "23.253"
        "37.235" "45.33" "45.90" "46.182" "51.15" "62.210"
        "64.6" "66.70" "74.82" "77.88" "78.46" "80.67"
        "80.80" "84.200" "85.214" "89.233" "91.239" "94.140"
        "101.226" "103.86" "104.236" "107.150" "108.61"
        "114.114" "115.159" "116.202" "116.203" "119.29"
        "134.195" "136.144" "139.59" "139.162" "149.112"
        "156.154" "159.69" "159.89" "168.95" "172.64"
        "172.104" "176.9" "176.103" "178.79" "185.121"
        "185.184" "185.222" "185.228" "185.253" "188.166"
        "193.17" "193.110" "194.36" "195.10" "195.46"
        "198.101" "199.85" "203.67" "203.198" "207.148"
        "208.67" "208.76" "209.244" "216.146" "217.160"
    )

    local new_dns=()
    local new_domains=()
    local found=0
    local tested=0

    while [ $found -lt $scan_count ] && [ $tested -lt 5000 ]; do
        local range="${RANGES[$((RANDOM % ${#RANGES[@]}))]}"
        local ip="${range}.$((RANDOM % 256)).$((RANDOM % 254 + 1))"
        tested=$((tested + 1))

        local r=$(timeout 2 dig @"$ip" google.com +short +time=1 +tries=1 2>/dev/null)
        if [ -n "$r" ] && echo "$r" | grep -qE '^[0-9]+\.[0-9]+'; then
            local r2=$(timeout 2 dig @"$ip" cloudflare.com +short +time=1 +tries=1 2>/dev/null)
            if [ -n "$r2" ] && echo "$r2" | grep -qE '^[0-9]+\.[0-9]+'; then
                local dup=false
                for e in "${new_dns[@]}"; do [ "$e" = "${ip}:${scan_port}" ] && { dup=true; break; }; done
                if [ "$dup" = false ]; then
                    found=$((found + 1))
                    new_dns+=("${ip}:${scan_port}")
                    new_domains+=("$scan_domain")
                    log "INFO" "AUTO-SCAN: [$found/$scan_count] Found ${ip}:${scan_port}"
                fi
            fi
        fi
    done

    if [ $found -gt 0 ]; then
        DNS_SERVERS=("${new_dns[@]}")
        DOMAINS=("${new_domains[@]}")
        TOTAL=${#DNS_SERVERS[@]}
        IDX=0

        # Save to config
        cat > "$CONFIG_FILE" << SCANEOF
# DNSTT-DNS-Changer Config - Auto-scanned $(date)
DNS_SERVERS=(
$(for s in "${DNS_SERVERS[@]}"; do echo "    \"$s\""; done)
)
DOMAINS=(
$(for d in "${DOMAINS[@]}"; do echo "    \"$d\""; done)
)
BINARY="${BINARY}"
PUBKEY_FILE="${PUBKEY_FILE}"
LOCAL_LISTEN="${LOCAL_LISTEN}"
PROTOCOL="${PROTOCOL:-udp}"
AUTO_RESTART_CHECK=${AUTO_RESTART_CHECK:-15}
MAX_FAILURES=${MAX_FAILURES:-2}
ALL_FAILED_WAIT=${ALL_FAILED_WAIT:-30}
AUTO_RESTART_ENABLED=${AUTO_RESTART_ENABLED:-true}
AUTO_RESTART_MAX_TRIES=${AUTO_RESTART_MAX_TRIES:-3}
SOCKS_TEST_ENABLED=${SOCKS_TEST_ENABLED:-false}
SOCKS_TEST_URL="${SOCKS_TEST_URL:-http://www.google.com}"
SOCKS_TEST_TIMEOUT=${SOCKS_TEST_TIMEOUT:-15}
AUTO_SCAN_ENABLED=${AUTO_SCAN_ENABLED:-false}
AUTO_SCAN_TRIGGER=${AUTO_SCAN_TRIGGER:-2}
AUTO_SCAN_COUNT=${AUTO_SCAN_COUNT:-30}
AUTO_SCAN_DOMAIN="${AUTO_SCAN_DOMAIN}"
AUTO_SCAN_PORT=${AUTO_SCAN_PORT:-53}
SCANEOF

        log "INFO" "AUTO-SCAN: Complete! Found $found DNS, replaced config"
    else
        log "ERROR" "AUTO-SCAN: No DNS found after $tested tests"
    fi
}

try_all_servers() {
    local tried=0
    while [ $tried -lt $TOTAL ]; do
        next_dns
        if start_dnstt; then
            sleep 10
            if is_alive; then
                log "INFO" "Connected on ${DNS_SERVERS[$IDX]}"
                FAILS=0
                return 0
            fi
        fi
        tried=$((tried + 1))
    done

    log "ERROR" "ALL $TOTAL servers failed!"

    # ═══ AUTO-SCAN TRIGGER ═══
    source "$CONFIG_FILE" 2>/dev/null
    local scan_on=${AUTO_SCAN_ENABLED:-false}
    local scan_trigger=${AUTO_SCAN_TRIGGER:-2}

    # Count how many working DNS we have left
    # If all failed, we have 0 working = trigger auto-scan
    if [ "$scan_on" = "true" ]; then
        log "INFO" "AUTO-SCAN triggered: all servers down"
        auto_scan

        # Try the new servers
        if [ ${#DNS_SERVERS[@]} -gt 0 ]; then
            log "INFO" "Trying newly scanned servers..."
            IDX=0
            TOTAL=${#DNS_SERVERS[@]}
            if start_dnstt; then
                sleep 10
                if is_alive; then
                    log "INFO" "Connected on new DNS ${DNS_SERVERS[$IDX]}"
                    FAILS=0
                    return 0
                fi
            fi
            # Try rest of new servers
            local t2=0
            while [ $t2 -lt $TOTAL ]; do
                next_dns
                if start_dnstt; then
                    sleep 10
                    if is_alive; then
                        log "INFO" "Connected on ${DNS_SERVERS[$IDX]}"
                        FAILS=0
                        return 0
                    fi
                fi
                t2=$((t2 + 1))
            done
        fi
    fi

    log "ERROR" "Waiting ${ALL_FAILED_WAIT:-30}s..."
    sleep "${ALL_FAILED_WAIT:-30}"
    FAILS=0
    return 1
}

trap 'log "INFO" "Shutdown"; nuke; exit 0' SIGTERM SIGINT SIGHUP

# ═══ MAIN ═══
log "INFO" "v1.9.0 | Servers=$TOTAL | Check=${CHECK}s | MaxFail=$MAX_FAIL"

if ! command -v curl &>/dev/null; then
    apt-get install -y -qq curl 2>/dev/null || yum install -y -q curl 2>/dev/null
fi

start_dnstt
FAILS=0

while true; do
    sleep "$CHECK"

    source "$CONFIG_FILE" 2>/dev/null
    CHECK=${AUTO_RESTART_CHECK:-15}
    MAX_FAIL=${MAX_FAILURES:-2}
    TOTAL=${#DNS_SERVERS[@]}

    if is_alive; then
        [ $FAILS -gt 0 ] && log "INFO" "Recovered after $FAILS fails"
        FAILS=0
    else
        FAILS=$((FAILS + 1))
        log "ERROR" "NOT WORKING! Fail $FAILS/$MAX_FAIL on ${DNS_SERVERS[$IDX]}"

        if [ $FAILS -ge $MAX_FAIL ]; then
            log "ERROR" "Switching DNS..."
            try_all_servers
        fi
    fi
done
