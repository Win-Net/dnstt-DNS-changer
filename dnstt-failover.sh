#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer Failover Engine v1.5.0
# https://github.com/Win-Net/dnstt-DNS-changer
#
# Logic:
# - Start dnstt on first DNS server
# - ONLY restart if process actually dies
# - If restart fails, switch to next DNS
# - Never touch a working connection
# ═══════════════════════════════════════════════════════════

CONFIG_FILE="/etc/dnstt-DNS-changer/config.conf"
VERSION="1.5.0"

if [ ! -f "$CONFIG_FILE" ]; then echo "[FATAL] Config not found: $CONFIG_FILE"; exit 1; fi
source "$CONFIG_FILE"

if [ ${#DNS_SERVERS[@]} -eq 0 ]; then echo "[FATAL] No DNS servers!"; exit 1; fi
if [ ${#DOMAINS[@]} -eq 0 ]; then echo "[FATAL] No domains!"; exit 1; fi
if [ ${#DNS_SERVERS[@]} -ne ${#DOMAINS[@]} ]; then echo "[FATAL] Server/domain count mismatch!"; exit 1; fi
if [ ! -f "$BINARY" ]; then echo "[FATAL] Binary not found: $BINARY"; exit 1; fi
if [ ! -x "$BINARY" ]; then chmod +x "$BINARY"; fi
if [ ! -f "$PUBKEY_FILE" ]; then echo "[FATAL] Key not found: $PUBKEY_FILE"; exit 1; fi

CURRENT_INDEX=0
CHILD_PID=0
RUNNING=true
TOTAL_SWITCHES=0
TOTAL_RESTARTS=0
LOG_TAG="dnstt-DNS-changer"
CHECK_INTERVAL=${AUTO_RESTART_CHECK:-10}

log_info()    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]    $1"; logger -t "$LOG_TAG" "INFO: $1" 2>/dev/null; }
log_warn()    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1"; logger -t "$LOG_TAG" "WARNING: $1" 2>/dev/null; }
log_error()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]   $1"; logger -t "$LOG_TAG" "ERROR: $1" 2>/dev/null; }
log_switch()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SWITCH]  $1"; logger -t "$LOG_TAG" "SWITCH: $1" 2>/dev/null; }
log_restart() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [RESTART] $1"; logger -t "$LOG_TAG" "RESTART: $1" 2>/dev/null; }

cleanup() {
    RUNNING=false
    log_info "Shutting down..."
    kill_all
    log_info "Stopped. Switches: $TOTAL_SWITCHES | Restarts: $TOTAL_RESTARTS"
    exit 0
}
trap cleanup SIGTERM SIGINT SIGHUP

get_port() { echo "${LOCAL_LISTEN##*:}"; }

kill_all() {
    local port=$(get_port)
    
    if [ $CHILD_PID -ne 0 ] && kill -0 $CHILD_PID 2>/dev/null; then
        kill -TERM $CHILD_PID 2>/dev/null
        sleep 2
        kill -0 $CHILD_PID 2>/dev/null && kill -9 $CHILD_PID 2>/dev/null
        wait $CHILD_PID 2>/dev/null
    fi
    CHILD_PID=0

    pkill -9 -f "dnstt-client" 2>/dev/null
    sleep 1

    if command -v fuser &>/dev/null; then
        fuser -k ${port}/tcp 2>/dev/null
    fi
    sleep 1

    # Wait for port to be free
    local w=0
    while ss -tlnp 2>/dev/null | grep -q ":${port}" && [ $w -lt 10 ]; do
        sleep 1
        w=$((w+1))
    done
}

start_dnstt() {
    local dns="${DNS_SERVERS[$CURRENT_INDEX]}"
    local domain="${DOMAINS[$CURRENT_INDEX]}"
    
    log_info "========================================"
    log_info "Connecting [$((CURRENT_INDEX+1))/${#DNS_SERVERS[@]}]"
    log_info "DNS: $dns | Domain: $domain"
    log_info "========================================"

    kill_all
    sleep 2

    if [ "$PROTOCOL" = "dot" ]; then
        $BINARY -dot "$dns" -pubkey-file "$PUBKEY_FILE" "$domain" "$LOCAL_LISTEN" &
    else
        $BINARY -udp "$dns" -pubkey-file "$PUBKEY_FILE" "$domain" "$LOCAL_LISTEN" &
    fi
    CHILD_PID=$!

    sleep 5

    if ! kill -0 $CHILD_PID 2>/dev/null; then
        log_error "Process died immediately!"
        CHILD_PID=0
        return 1
    fi

    log_info "Process started (PID: $CHILD_PID)"
    return 0
}

# ═══════════════════════════════════════════════════════════
# MAIN LOOP - Simple logic:
# Is the process alive? Yes = do nothing. No = restart.
# ═══════════════════════════════════════════════════════════

log_info "DNSTT-DNS-Changer v$VERSION started"
log_info "Servers: ${#DNS_SERVERS[@]} | Check interval: ${CHECK_INTERVAL}s"
log_info "Logic: Only restart when process dies. Never kill working connection."

# Initial start
start_dnstt

RESTART_FAIL_COUNT=0

while $RUNNING; do
    sleep "$CHECK_INTERVAL"
    $RUNNING || break

    # Reload config
    source "$CONFIG_FILE" 2>/dev/null
    CHECK_INTERVAL=${AUTO_RESTART_CHECK:-10}

    # ═══ ONLY CHECK: Is the process alive? ═══
    if kill -0 $CHILD_PID 2>/dev/null; then
        # Process is alive = EVERYTHING IS FINE = DO NOTHING
        RESTART_FAIL_COUNT=0
        continue
    fi

    # ═══ Process is DEAD! ═══
    log_error "Process $CHILD_PID is DEAD!"
    TOTAL_RESTARTS=$((TOTAL_RESTARTS + 1))
    RESTART_FAIL_COUNT=$((RESTART_FAIL_COUNT + 1))

    log_restart "Restart #$TOTAL_RESTARTS (attempt $RESTART_FAIL_COUNT on current server)"

    # Try restart same server first
    if [ $RESTART_FAIL_COUNT -le ${AUTO_RESTART_MAX_TRIES:-3} ]; then
        log_info "Restarting same server: ${DNS_SERVERS[$CURRENT_INDEX]}"
        if start_dnstt; then
            log_info "Restart successful!"
            continue
        fi
        log_error "Restart failed!"
    fi

    # Same server failed too many times, switch to next
    log_error "Server ${DNS_SERVERS[$CURRENT_INDEX]} failed $RESTART_FAIL_COUNT times. Switching..."
    RESTART_FAIL_COUNT=0

    FULL_ROUND=0
    ATTEMPTS=0

    while $RUNNING; do
        # Move to next server
        local old="${DNS_SERVERS[$CURRENT_INDEX]}"
        CURRENT_INDEX=$(( (CURRENT_INDEX + 1) % ${#DNS_SERVERS[@]} ))
        TOTAL_SWITCHES=$((TOTAL_SWITCHES + 1))
        log_switch "Changed: $old -> ${DNS_SERVERS[$CURRENT_INDEX]} (Switch #$TOTAL_SWITCHES)"

        sleep 3

        if start_dnstt; then
            log_info "Connected to ${DNS_SERVERS[$CURRENT_INDEX]}"
            break
        fi

        ATTEMPTS=$((ATTEMPTS + 1))
        if [ $ATTEMPTS -ge ${#DNS_SERVERS[@]} ]; then
            FULL_ROUND=$((FULL_ROUND + 1))
            if [ $FULL_ROUND -ge 3 ]; then
                log_error "All servers down! Waiting 60s..."
                sleep 60
            else
                log_error "All servers down! Waiting ${ALL_FAILED_WAIT:-30}s..."
                sleep "${ALL_FAILED_WAIT:-30}"
            fi
            ATTEMPTS=0
        fi
    done
done
