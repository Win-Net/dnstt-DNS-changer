#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer v1.7.2 - Fixed
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
        sleep 1
        i=$((i+1))
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
            else
                log "WARNING" "DNS ${DNS_SERVERS[$IDX]} not working"
            fi
        else
            log "ERROR" "Failed to start on ${DNS_SERVERS[$IDX]}"
        fi
        tried=$((tried + 1))
    done

    # All failed
    log "ERROR" "ALL $TOTAL servers failed! Waiting 30s..."
    sleep 30
    FAILS=0
    return 1
}

trap 'log "INFO" "Shutdown"; nuke; exit 0' SIGTERM SIGINT SIGHUP

# ═══ MAIN ═══
log "INFO" "v1.7.2 | Servers=$TOTAL | Check=${CHECK}s | MaxFail=$MAX_FAIL"

if ! command -v curl &>/dev/null; then
    log "WARNING" "Installing curl..."
    apt-get install -y -qq curl 2>/dev/null || yum install -y -q curl 2>/dev/null
fi

start_dnstt
FAILS=0

while true; do
    sleep "$CHECK"

    # Reload config
    source "$CONFIG_FILE" 2>/dev/null
    CHECK=${AUTO_RESTART_CHECK:-15}
    MAX_FAIL=${MAX_FAILURES:-2}

    if is_alive; then
        if [ $FAILS -gt 0 ]; then
            log "INFO" "Recovered after $FAILS fails"
        fi
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
