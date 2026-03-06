#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer v1.6.0 - Stable Failover
# https://github.com/Win-Net/dnstt-DNS-changer
#
# Logic:
# 1. Start dnstt-client on DNS server #1
# 2. Monitor: is the process alive?
# 3. If process dies → switch to NEXT DNS → restart
# 4. Never touch a working process
# ═══════════════════════════════════════════════════════════

CONFIG_FILE="/etc/dnstt-DNS-changer/config.conf"

if [ ! -f "$CONFIG_FILE" ]; then echo "[FATAL] Config not found"; exit 1; fi
source "$CONFIG_FILE"

if [ ${#DNS_SERVERS[@]} -eq 0 ]; then echo "[FATAL] No DNS servers"; exit 1; fi
if [ ${#DNS_SERVERS[@]} -ne ${#DOMAINS[@]} ]; then echo "[FATAL] Mismatch"; exit 1; fi
if [ ! -f "$BINARY" ]; then echo "[FATAL] No binary: $BINARY"; exit 1; fi
[ ! -x "$BINARY" ] && chmod +x "$BINARY"
if [ ! -f "$PUBKEY_FILE" ]; then echo "[FATAL] No key: $PUBKEY_FILE"; exit 1; fi

IDX=0
TOTAL=${#DNS_SERVERS[@]}
TAG="dnstt-DNS-changer"
SWITCHES=0
CHECK=${AUTO_RESTART_CHECK:-10}

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2"; logger -t "$TAG" "$1: $2" 2>/dev/null; }

get_port() { echo "${LOCAL_LISTEN##*:}"; }

# Clean kill everything
nuke() {
    pkill -9 -f "dnstt-client" 2>/dev/null
    sleep 1
    local port=$(get_port)
    if command -v fuser &>/dev/null; then fuser -k ${port}/tcp 2>/dev/null; fi
    sleep 1
    # wait port free
    local i=0
    while ss -tlnp 2>/dev/null | grep -q ":${port}" && [ $i -lt 10 ]; do sleep 1; i=$((i+1)); done
}

# Start dnstt-client directly (not as background of background)
run() {
    local dns="${DNS_SERVERS[$IDX]}"
    local domain="${DOMAINS[$IDX]}"
    log "INFO" "========================================"
    log "INFO" "Starting [$((IDX+1))/$TOTAL] DNS: $dns Domain: $domain"
    log "INFO" "========================================"

    nuke

    if [ "${PROTOCOL:-udp}" = "dot" ]; then
        exec_cmd="$BINARY -dot $dns -pubkey-file $PUBKEY_FILE $domain $LOCAL_LISTEN"
    else
        exec_cmd="$BINARY -udp $dns -pubkey-file $PUBKEY_FILE $domain $LOCAL_LISTEN"
    fi

    # Run dnstt-client and wait for it to exit
    $exec_cmd &
    DNSTT_PID=$!
    log "INFO" "Process started PID=$DNSTT_PID"
    
    # Wait for process to die (this blocks!)
    wait $DNSTT_PID 2>/dev/null
    EXIT_CODE=$?
    
    log "ERROR" "Process $DNSTT_PID exited with code $EXIT_CODE"
    return $EXIT_CODE
}

# Next DNS
next() {
    local old="${DNS_SERVERS[$IDX]}"
    IDX=$(( (IDX + 1) % TOTAL ))
    SWITCHES=$((SWITCHES + 1))
    log "SWITCH" "DNS changed: $old -> ${DNS_SERVERS[$IDX]} (switch #$SWITCHES)"
}

# Shutdown handler
trap 'log "INFO" "Shutdown..."; nuke; exit 0' SIGTERM SIGINT SIGHUP

# ═══ MAIN ═══
log "INFO" "DNSTT-DNS-Changer v1.6.0 | Servers: $TOTAL | Check: ${CHECK}s"

FAILS=0

while true; do
    # Run and WAIT for it to die
    run

    # Process died, go to NEXT dns first, then restart
    FAILS=$((FAILS + 1))
    log "ERROR" "Connection lost! Fail #$FAILS"

    # Switch to next DNS
    next

    # If we tried all servers, wait longer
    if [ $((FAILS % TOTAL)) -eq 0 ]; then
        local wait_time=${ALL_FAILED_WAIT:-30}
        [ $FAILS -ge $((TOTAL * 3)) ] && wait_time=60
        log "ERROR" "All $TOTAL servers tried. Waiting ${wait_time}s..."
        sleep $wait_time
    else
        sleep 3
    fi
done
