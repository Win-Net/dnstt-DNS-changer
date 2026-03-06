#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer Failover Engine v1.4.0
# https://github.com/Win-Net/dnstt-DNS-changer
# ═══════════════════════════════════════════════════════════

CONFIG_FILE="/etc/dnstt-DNS-changer/config.conf"
VERSION="1.4.0"

if [ ! -f "$CONFIG_FILE" ]; then echo "[FATAL] Config not found: $CONFIG_FILE"; exit 1; fi
source "$CONFIG_FILE"

if [ ${#DNS_SERVERS[@]} -eq 0 ]; then echo "[FATAL] No DNS servers!"; exit 1; fi
if [ ${#DOMAINS[@]} -eq 0 ]; then echo "[FATAL] No domains!"; exit 1; fi
if [ ${#DNS_SERVERS[@]} -ne ${#DOMAINS[@]} ]; then echo "[FATAL] Server/domain count mismatch!"; exit 1; fi
if [ ! -f "$BINARY" ]; then echo "[FATAL] Binary not found: $BINARY"; exit 1; fi
if [ ! -x "$BINARY" ]; then chmod +x "$BINARY"; fi
if [ ! -f "$PUBKEY_FILE" ]; then echo "[FATAL] Key not found: $PUBKEY_FILE"; exit 1; fi

CURRENT_INDEX=0
FAILURE_COUNT=0
CHILD_PID=0
RUNNING=true
TOTAL_SWITCHES=0
TOTAL_RESTARTS=0
LOG_TAG="dnstt-DNS-changer"

log_info()    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]    $1"; logger -t "$LOG_TAG" "INFO: $1" 2>/dev/null; }
log_warn()    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1"; logger -t "$LOG_TAG" "WARNING: $1" 2>/dev/null; }
log_error()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]   $1"; logger -t "$LOG_TAG" "ERROR: $1" 2>/dev/null; }
log_switch()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SWITCH]  $1"; logger -t "$LOG_TAG" "SWITCH: $1" 2>/dev/null; }
log_restart() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [RESTART] $1"; logger -t "$LOG_TAG" "RESTART: $1" 2>/dev/null; }

cleanup() {
    RUNNING=false
    log_info "Shutting down..."
    kill_all_dnstt
    log_info "Stopped. Switches: $TOTAL_SWITCHES | Restarts: $TOTAL_RESTARTS"
    exit 0
}
trap cleanup SIGTERM SIGINT SIGHUP

get_port() {
    echo "${LOCAL_LISTEN##*:}"
}

kill_all_dnstt() {
    local port=$(get_port)

    # Kill our child
    if [ $CHILD_PID -ne 0 ] && kill -0 $CHILD_PID 2>/dev/null; then
        kill -TERM $CHILD_PID 2>/dev/null
        sleep 2
        kill -0 $CHILD_PID 2>/dev/null && kill -9 $CHILD_PID 2>/dev/null
        wait $CHILD_PID 2>/dev/null
    fi
    CHILD_PID=0

    # Kill ALL dnstt-client
    pkill -9 -f "dnstt-client" 2>/dev/null
    sleep 1

    # Kill anything on our port
    if command -v fuser &>/dev/null; then
        fuser -k ${port}/tcp 2>/dev/null
        sleep 1
    fi

    local pids=$(ss -tlnp 2>/dev/null | grep ":${port}" | grep -oP 'pid=\K[0-9]+' | sort -u)
    if [ -n "$pids" ]; then
        for p in $pids; do kill -9 "$p" 2>/dev/null; done
        sleep 1
    fi

    if command -v lsof &>/dev/null; then
        lsof -ti :${port} 2>/dev/null | xargs -r kill -9 2>/dev/null
        sleep 1
    fi

    # Wait for port
    local w=0
    while ss -tlnp 2>/dev/null | grep -q ":${port}" && [ $w -lt 10 ]; do
        sleep 1
        w=$((w+1))
    done
}

wait_port_free() {
    local port=$(get_port)
    local w=0
    while ss -tlnp 2>/dev/null | grep -q ":${port}" && [ $w -lt 15 ]; do
        sleep 1
        w=$((w+1))
    done
    if ss -tlnp 2>/dev/null | grep -q ":${port}"; then
        return 1
    fi
    return 0
}

wait_port_open() {
    local port=$(get_port)
    local w=0
    while ! ss -tlnp 2>/dev/null | grep -q ":${port}" && [ $w -lt 15 ]; do
        sleep 1
        w=$((w+1))
    done
    if ss -tlnp 2>/dev/null | grep -q ":${port}"; then
        return 0
    fi
    return 1
}

start_dnstt() {
    local dns="${DNS_SERVERS[$CURRENT_INDEX]}"
    local domain="${DOMAINS[$CURRENT_INDEX]}"
    log_info "========================================"
    log_info "Connecting [$((CURRENT_INDEX+1))/${#DNS_SERVERS[@]}]"
    log_info "DNS: $dns | Domain: $domain | Protocol: $PROTOCOL"
    log_info "========================================"

    kill_all_dnstt

    if ! wait_port_free; then
        log_error "Port $(get_port) cannot be freed!"
        return 1
    fi

    sleep 1

    if [ "$PROTOCOL" = "dot" ]; then
        $BINARY -dot "$dns" -pubkey-file "$PUBKEY_FILE" "$domain" "$LOCAL_LISTEN" &
    else
        $BINARY -udp "$dns" -pubkey-file "$PUBKEY_FILE" "$domain" "$LOCAL_LISTEN" &
    fi
    CHILD_PID=$!
    FAILURE_COUNT=0

    sleep 3

    if ! kill -0 $CHILD_PID 2>/dev/null; then
        log_error "Process died immediately!"
        CHILD_PID=0
        return 1
    fi

    if wait_port_open; then
        log_info "Started OK (PID: $CHILD_PID, Port: $(get_port))"
        return 0
    fi

    if kill -0 $CHILD_PID 2>/dev/null; then
        log_warn "Process alive but port slow, continuing..."
        return 0
    fi

    log_error "Process died during startup"
    CHILD_PID=0
    return 1
}

is_connection_alive() {
    # Check 1: Process
    if [ $CHILD_PID -eq 0 ] || ! kill -0 $CHILD_PID 2>/dev/null; then
        return 1
    fi

    # Check 2: Port
    local port=$(get_port)
    if ! ss -tlnp 2>/dev/null | grep -q ":${port}"; then
        return 1
    fi

    # Check 3: SOCKS (optional)
    if [ "${SOCKS_TEST_ENABLED}" = "true" ] && command -v curl &>/dev/null; then
        if ! timeout "${SOCKS_TEST_TIMEOUT:-15}" curl -s --socks5 "$LOCAL_LISTEN" "${SOCKS_TEST_URL:-http://www.google.com}" > /dev/null 2>&1; then
            return 1
        fi
    fi

    return 0
}

full_restart() {
    TOTAL_RESTARTS=$((TOTAL_RESTARTS + 1))
    log_restart "Full restart #$TOTAL_RESTARTS on ${DNS_SERVERS[$CURRENT_INDEX]}"
    start_dnstt
}

switch_to_next() {
    local old="${DNS_SERVERS[$CURRENT_INDEX]}"
    kill_all_dnstt
    CURRENT_INDEX=$(( (CURRENT_INDEX + 1) % ${#DNS_SERVERS[@]} ))
    TOTAL_SWITCHES=$((TOTAL_SWITCHES + 1))
    log_switch "Changed: $old -> ${DNS_SERVERS[$CURRENT_INDEX]} (Switch #$TOTAL_SWITCHES)"
    sleep 2
}

# ═══════════════════════════════════════════════════════════
# MAIN LOOP
# ═══════════════════════════════════════════════════════════

log_info "DNSTT-DNS-Changer v$VERSION started"
log_info "Servers: ${#DNS_SERVERS[@]} | Auto-restart: ${AUTO_RESTART_ENABLED:-true}"

# Initial start
if ! start_dnstt; then
    log_error "Initial start failed, trying next..."
    switch_to_next
    start_dnstt
fi

RESTART_TRIES=0
CHECK_INTERVAL=${AUTO_RESTART_CHECK:-20}

while $RUNNING; do
    sleep "$CHECK_INTERVAL"
    $RUNNING || break

    # Reload config live
    source "$CONFIG_FILE" 2>/dev/null
    CHECK_INTERVAL=${AUTO_RESTART_CHECK:-20}
    local max_fail=${MAX_FAILURES:-3}
    local auto_on=${AUTO_RESTART_ENABLED:-true}
    local auto_max=${AUTO_RESTART_MAX_TRIES:-3}

    if is_connection_alive; then
        if [ $FAILURE_COUNT -gt 0 ]; then
            log_info "Recovered after $FAILURE_COUNT failures"
        fi
        FAILURE_COUNT=0
        RESTART_TRIES=0
    else
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        log_warn "DEAD! Failure $FAILURE_COUNT/$max_fail on ${DNS_SERVERS[$CURRENT_INDEX]}"

        # AUTO RESTART: try same server first
        if [ "$auto_on" = "true" ]; then
            RESTART_TRIES=$((RESTART_TRIES + 1))
            log_restart "Auto-restart try $RESTART_TRIES/$auto_max"
            full_restart
            sleep 8
            if is_connection_alive; then
                log_info "Auto-restart SUCCESS!"
                FAILURE_COUNT=0
                RESTART_TRIES=0
                continue
            else
                log_warn "Auto-restart failed"
            fi
        fi

        # Enough failures, switch server
        if [ $FAILURE_COUNT -ge $max_fail ] || [ $RESTART_TRIES -ge $auto_max ]; then
            log_error "Server ${DNS_SERVERS[$CURRENT_INDEX]} DEAD! Switching..."
            FAILURE_COUNT=0
            RESTART_TRIES=0
            FULL_ROUND=0
            ATTEMPTS=0

            while $RUNNING; do
                switch_to_next
                if start_dnstt; then
                    sleep 8
                    if is_connection_alive; then
                        log_info "Connected to ${DNS_SERVERS[$CURRENT_INDEX]}"
                        break
                    elif kill -0 $CHILD_PID 2>/dev/null; then
                        log_info "Process running, giving it a chance..."
                        break
                    fi
                fi
                ATTEMPTS=$((ATTEMPTS + 1))
                if [ $ATTEMPTS -ge ${#DNS_SERVERS[@]} ]; then
                    FULL_ROUND=$((FULL_ROUND + 1))
                    if [ $FULL_ROUND -ge 3 ]; then
                        log_error "All down! Waiting 60s..."
                        sleep 60
                    else
                        log_error "All down! Waiting ${ALL_FAILED_WAIT:-30}s..."
                        sleep "${ALL_FAILED_WAIT:-30}"
                    fi
                    ATTEMPTS=0
                fi
            done
        fi
    fi
done
