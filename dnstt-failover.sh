#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer Failover Engine v1.3.0
# https://github.com/Win-Net/dnstt-DNS-changer
# ═══════════════════════════════════════════════════════════

CONFIG_FILE="/etc/dnstt-DNS-changer/config.conf"
VERSION="1.3.0"

if [ ! -f "$CONFIG_FILE" ]; then echo "[FATAL] Config not found: $CONFIG_FILE"; exit 1; fi
source "$CONFIG_FILE"

if [ ${#DNS_SERVERS[@]} -eq 0 ]; then echo "[FATAL] No DNS servers!"; exit 1; fi
if [ ${#DOMAINS[@]} -eq 0 ]; then echo "[FATAL] No domains!"; exit 1; fi
if [ ${#DNS_SERVERS[@]} -ne ${#DOMAINS[@]} ]; then echo "[FATAL] Server/domain count mismatch!"; exit 1; fi
if [ ! -f "$BINARY" ]; then echo "[FATAL] Binary not found: $BINARY"; exit 1; fi
if [ ! -f "$PUBKEY_FILE" ]; then echo "[FATAL] Key not found: $PUBKEY_FILE"; exit 1; fi

CURRENT_INDEX=0
FAILURE_COUNT=0
CHILD_PID=0
RUNNING=true
TOTAL_SWITCHES=0
TOTAL_RESTARTS=0
LOG_TAG="dnstt-DNS-changer"

# Auto-restart settings
AUTO_RESTART=${AUTO_RESTART_ENABLED:-true}
AUTO_RESTART_INTERVAL=${AUTO_RESTART_CHECK:-20}
AUTO_RESTART_MAX=${AUTO_RESTART_MAX_TRIES:-5}

log_info()    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]    $1"; logger -t "$LOG_TAG" "INFO: $1"; }
log_warn()    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1"; logger -t "$LOG_TAG" "WARNING: $1"; }
log_error()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]   $1"; logger -t "$LOG_TAG" "ERROR: $1"; }
log_switch()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SWITCH]  $1"; logger -t "$LOG_TAG" "SWITCH: $1"; }
log_restart() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [RESTART] $1"; logger -t "$LOG_TAG" "RESTART: $1"; }

cleanup() {
    RUNNING=false
    log_info "Shutting down..."
    kill_all_dnstt
    log_info "Stopped. Switches: $TOTAL_SWITCHES | Restarts: $TOTAL_RESTARTS"
    exit 0
}
trap cleanup SIGTERM SIGINT SIGHUP

# ═══ Kill ALL dnstt processes completely ═══
kill_all_dnstt() {
    local port="${LOCAL_LISTEN##*:}"

    # Kill child if we know it
    if [ $CHILD_PID -ne 0 ] && kill -0 $CHILD_PID 2>/dev/null; then
        kill -TERM $CHILD_PID 2>/dev/null
        local w=0
        while kill -0 $CHILD_PID 2>/dev/null && [ $w -lt 3 ]; do sleep 1; w=$((w+1)); done
        kill -0 $CHILD_PID 2>/dev/null && kill -9 $CHILD_PID 2>/dev/null
        wait $CHILD_PID 2>/dev/null
    fi
    CHILD_PID=0

    # Kill ALL dnstt-client processes
    pkill -9 -f "dnstt-client" 2>/dev/null
    sleep 1

    # Double check - kill anything on our port
    local pids=$(ss -tlnp 2>/dev/null | grep ":${port}" | grep -o 'pid=[0-9]*' | cut -d= -f2 | sort -u)
    if [ -n "$pids" ]; then
        echo "$pids" | while read p; do
            [ -n "$p" ] && kill -9 "$p" 2>/dev/null
        done
        sleep 1
    fi

    # Triple check with lsof
    if command -v lsof &>/dev/null; then
        lsof -ti :${port} 2>/dev/null | while read p; do
            kill -9 "$p" 2>/dev/null
        done
        sleep 1
    fi

    # Final check
    if ss -tlnp 2>/dev/null | grep -q ":${port}"; then
        log_warn "Port $port still busy, waiting 5s for OS to release..."
        sleep 5
    fi
}

# ═══ Start DNSTT ═══
start_dnstt() {
    local dns="${DNS_SERVERS[$CURRENT_INDEX]}"
    local domain="${DOMAINS[$CURRENT_INDEX]}"
    log_info "========================================"
    log_info "Connecting [$((CURRENT_INDEX+1))/${#DNS_SERVERS[@]}]"
    log_info "DNS: $dns | Domain: $domain"
    log_info "========================================"

    # Clean kill everything first
    kill_all_dnstt

    # Wait for port to be free
    local port="${LOCAL_LISTEN##*:}"
    local wait=0
    while ss -tlnp 2>/dev/null | grep -q ":${port}" && [ $wait -lt 10 ]; do
        sleep 1
        wait=$((wait+1))
    done

    if ss -tlnp 2>/dev/null | grep -q ":${port}"; then
        log_error "Port $port cannot be freed!"
        return 1
    fi

    # Start process
    if [ "$PROTOCOL" = "dot" ]; then
        $BINARY -dot "$dns" -pubkey-file "$PUBKEY_FILE" "$domain" "$LOCAL_LISTEN" &
    else
        $BINARY -udp "$dns" -pubkey-file "$PUBKEY_FILE" "$domain" "$LOCAL_LISTEN" &
    fi
    CHILD_PID=$!
    FAILURE_COUNT=0

    # Wait for startup
    sleep 5

    if ! kill -0 $CHILD_PID 2>/dev/null; then
        log_error "Process died immediately!"
        CHILD_PID=0
        return 1
    fi

    # Wait for port to open
    local pc=0
    while [ $pc -lt 10 ]; do
        if ss -tlnp 2>/dev/null | grep -q ":${port}"; then
            log_info "Started OK (PID: $CHILD_PID, Port: $port)"
            return 0
        fi
        sleep 1
        pc=$((pc+1))
    done

    log_warn "Process running but port slow to open"
    return 0
}

# ═══ Full restart of current server ═══
full_restart() {
    TOTAL_RESTARTS=$((TOTAL_RESTARTS + 1))
    log_restart "Full restart #$TOTAL_RESTARTS on ${DNS_SERVERS[$CURRENT_INDEX]}"
    kill_all_dnstt
    sleep 3
    start_dnstt
}

# ═══ Health Check ═══
health_check() {
    # Check 1: Process alive?
    if [ $CHILD_PID -eq 0 ] || ! kill -0 $CHILD_PID 2>/dev/null; then
        log_warn "Process not running"
        return 1
    fi

    # Check 2: Port listening?
    local port="${LOCAL_LISTEN##*:}"
    if ! ss -tlnp 2>/dev/null | grep -q ":${port}"; then
        log_warn "Port $port not listening"
        return 1
    fi

    # Check 3: SOCKS test
    if [ "$SOCKS_TEST_ENABLED" = "true" ] && command -v curl &>/dev/null; then
        if ! timeout "$SOCKS_TEST_TIMEOUT" curl -s --socks5 "$LOCAL_LISTEN" "$SOCKS_TEST_URL" > /dev/null 2>&1; then
            log_warn "SOCKS test failed"
            return 1
        fi
    fi

    return 0
}

# ═══ Switch to next ═══
switch_to_next() {
    local old="${DNS_SERVERS[$CURRENT_INDEX]}"
    kill_all_dnstt
    CURRENT_INDEX=$(( (CURRENT_INDEX + 1) % ${#DNS_SERVERS[@]} ))
    TOTAL_SWITCHES=$((TOTAL_SWITCHES + 1))
    log_switch "Changed: $old -> ${DNS_SERVERS[$CURRENT_INDEX]} (Switch #$TOTAL_SWITCHES)"
    sleep 3
}

# ═══════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════

log_info "DNSTT-DNS-Changer v$VERSION started"
log_info "Servers: ${#DNS_SERVERS[@]} | Check: ${AUTO_RESTART_INTERVAL}s | Max fail: $MAX_FAILURES"
log_info "Auto-restart: $AUTO_RESTART"

# Initial start
if ! start_dnstt; then
    log_error "Initial start failed, trying next..."
    switch_to_next
    start_dnstt
fi

RESTART_TRIES=0

while $RUNNING; do
    sleep "$AUTO_RESTART_INTERVAL"
    $RUNNING || break

    # Reload config for auto-restart settings (so user can change without restart)
    source "$CONFIG_FILE" 2>/dev/null
    AUTO_RESTART=${AUTO_RESTART_ENABLED:-true}
    AUTO_RESTART_INTERVAL=${AUTO_RESTART_CHECK:-20}

    if health_check; then
        # All good
        if [ $FAILURE_COUNT -gt 0 ]; then
            log_info "Connection recovered after $FAILURE_COUNT failures"
        fi
        FAILURE_COUNT=0
        RESTART_TRIES=0
    else
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        log_warn "Failure $FAILURE_COUNT/$MAX_FAILURES on ${DNS_SERVERS[$CURRENT_INDEX]}"

        # Auto-restart: try restarting same server first
        if [ "$AUTO_RESTART" = "true" ] && [ $FAILURE_COUNT -lt $MAX_FAILURES ]; then
            RESTART_TRIES=$((RESTART_TRIES + 1))
            if [ $RESTART_TRIES -le $AUTO_RESTART_MAX ]; then
                log_restart "Auto-restart attempt $RESTART_TRIES (same server)"
                full_restart
                sleep 5
                if health_check; then
                    log_info "Auto-restart successful!"
                    FAILURE_COUNT=0
                    RESTART_TRIES=0
                    continue
                fi
            fi
        fi

        # Max failures reached, switch server
        if [ $FAILURE_COUNT -ge $MAX_FAILURES ]; then
            log_error "Server ${DNS_SERVERS[$CURRENT_INDEX]} down!"
            RESTART_TRIES=0
            FULL_ROUND=0
            ATTEMPTS=0

            while $RUNNING; do
                switch_to_next
                if start_dnstt; then
                    sleep 5
                    if health_check; then
                        log_info "Connected to ${DNS_SERVERS[$CURRENT_INDEX]}"
                        FAILURE_COUNT=0
                        break
                    elif kill -0 $CHILD_PID 2>/dev/null; then
                        log_info "Process running on ${DNS_SERVERS[$CURRENT_INDEX]}, continuing..."
                        FAILURE_COUNT=0
                        break
                    fi
                fi
                ATTEMPTS=$((ATTEMPTS + 1))
                if [ $ATTEMPTS -ge ${#DNS_SERVERS[@]} ]; then
                    FULL_ROUND=$((FULL_ROUND + 1))
                    log_error "All servers failed! Round $FULL_ROUND"
                    if [ $FULL_ROUND -ge 3 ]; then
                        log_error "Waiting 60s..."
                        sleep 60
                    else
                        log_error "Waiting ${ALL_FAILED_WAIT}s..."
                        sleep "$ALL_FAILED_WAIT"
                    fi
                    ATTEMPTS=0
                fi
            done
        fi
    fi
done
