#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer Failover Engine v1.1.0
# https://github.com/Win-Net/dnstt-DNS-changer
# ═══════════════════════════════════════════════════════════

CONFIG_FILE="/etc/dnstt-DNS-changer/config.conf"
VERSION="1.1.0"

if [ ! -f "$CONFIG_FILE" ]; then echo "[FATAL] Config not found: $CONFIG_FILE"; exit 1; fi
source "$CONFIG_FILE"

if [ ${#DNS_SERVERS[@]} -eq 0 ]; then echo "[FATAL] No DNS servers!"; exit 1; fi
if [ ${#DOMAINS[@]} -eq 0 ]; then echo "[FATAL] No domains!"; exit 1; fi
if [ ${#DNS_SERVERS[@]} -ne ${#DOMAINS[@]} ]; then echo "[FATAL] Server/domain count mismatch!"; exit 1; fi
if [ ! -f "$BINARY" ]; then echo "[FATAL] Binary not found: $BINARY"; exit 1; fi
if [ ! -f "$PUBKEY_FILE" ]; then echo "[FATAL] Public key not found: $PUBKEY_FILE"; exit 1; fi

CURRENT_INDEX=0
FAILURE_COUNT=0
CHILD_PID=0
RUNNING=true
TOTAL_SWITCHES=0
LOG_TAG="dnstt-DNS-changer"

log_info()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]    $1"; logger -t "$LOG_TAG" "INFO: $1"; }
log_warn()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1"; logger -t "$LOG_TAG" "WARNING: $1"; }
log_error()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]   $1"; logger -t "$LOG_TAG" "ERROR: $1"; }
log_switch() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SWITCH]  $1"; logger -t "$LOG_TAG" "SWITCH: $1"; }

cleanup() {
    RUNNING=false
    log_info "Shutting down..."
    kill_dnstt
    log_info "Stopped. Total switches: $TOTAL_SWITCHES"
    exit 0
}
trap cleanup SIGTERM SIGINT SIGHUP

kill_dnstt() {
    if [ $CHILD_PID -ne 0 ]; then
        if kill -0 $CHILD_PID 2>/dev/null; then
            log_info "Killing process $CHILD_PID (SIGTERM)..."
            kill -TERM $CHILD_PID 2>/dev/null
            local wait_count=0
            while kill -0 $CHILD_PID 2>/dev/null && [ $wait_count -lt 5 ]; do
                sleep 1
                wait_count=$((wait_count + 1))
            done
        fi
        if kill -0 $CHILD_PID 2>/dev/null; then
            log_warn "Force killing (SIGKILL)..."
            kill -9 $CHILD_PID 2>/dev/null
            sleep 1
        fi
        wait $CHILD_PID 2>/dev/null
        CHILD_PID=0
    fi

    local port="${LOCAL_LISTEN##*:}"
    local remaining=$(pgrep -f "dnstt-client.*${port}" 2>/dev/null)
    if [ -n "$remaining" ]; then
        log_warn "Killing remaining processes: $remaining"
        echo "$remaining" | while read pid; do
            kill -9 "$pid" 2>/dev/null
        done
        sleep 1
    fi

    local port_pid=$(ss -tlnp 2>/dev/null | grep ":${port}" | grep -o 'pid=[0-9]*' | cut -d= -f2)
    if [ -n "$port_pid" ]; then
        log_warn "Port $port still occupied by PID $port_pid, killing..."
        kill -9 "$port_pid" 2>/dev/null
        sleep 1
    fi

    if ss -tlnp 2>/dev/null | grep -q ":${port}"; then
        log_error "Port $port STILL occupied! Waiting 5s..."
        sleep 5
    fi
    log_info "Cleanup complete"
}

start_dnstt() {
    local dns="${DNS_SERVERS[$CURRENT_INDEX]}"
    local domain="${DOMAINS[$CURRENT_INDEX]}"
    log_info "========================================"
    log_info "Connecting [$((CURRENT_INDEX+1))/${#DNS_SERVERS[@]}]"
    log_info "DNS: $dns | Domain: $domain | Protocol: $PROTOCOL"
    log_info "========================================"

    kill_dnstt
    sleep 2

    if [ "$PROTOCOL" = "dot" ]; then
        $BINARY -dot "$dns" -pubkey-file "$PUBKEY_FILE" "$domain" "$LOCAL_LISTEN" &
    else
        $BINARY -udp "$dns" -pubkey-file "$PUBKEY_FILE" "$domain" "$LOCAL_LISTEN" &
    fi
    CHILD_PID=$!
    FAILURE_COUNT=0
    sleep 5

    if ! kill -0 $CHILD_PID 2>/dev/null; then
        log_error "Process died immediately!"
        CHILD_PID=0
        return 1
    fi

    local port="${LOCAL_LISTEN##*:}"
    local port_check=0
    while [ $port_check -lt 5 ]; do
        if ss -tlnp 2>/dev/null | grep -q ":${port}"; then
            log_info "Started successfully (PID: $CHILD_PID, Port: $port)"
            return 0
        fi
        sleep 1
        port_check=$((port_check + 1))
    done
    log_warn "Process running but port not listening yet"
    return 0
}

health_check() {
    if ! kill -0 $CHILD_PID 2>/dev/null; then
        log_warn "Process dead"
        return 1
    fi
    local port="${LOCAL_LISTEN##*:}"
    if ! ss -tlnp 2>/dev/null | grep -q ":${port}" 2>/dev/null; then
        if ! netstat -tlnp 2>/dev/null | grep -q ":${port}" 2>/dev/null; then
            log_warn "Port $port not listening"
            return 1
        fi
    fi
    if [ "$SOCKS_TEST_ENABLED" = "true" ] && command -v curl &>/dev/null; then
        if ! timeout "$SOCKS_TEST_TIMEOUT" curl -s --socks5 "$LOCAL_LISTEN" "$SOCKS_TEST_URL" > /dev/null 2>&1; then
            log_warn "SOCKS test failed"
            return 1
        fi
    fi
    return 0
}

switch_to_next() {
    local old="${DNS_SERVERS[$CURRENT_INDEX]}"
    kill_dnstt
    CURRENT_INDEX=$(( (CURRENT_INDEX + 1) % ${#DNS_SERVERS[@]} ))
    TOTAL_SWITCHES=$((TOTAL_SWITCHES + 1))
    log_switch "Changed: $old -> ${DNS_SERVERS[$CURRENT_INDEX]} (Switch #$TOTAL_SWITCHES)"
    sleep 3
}

log_info "DNSTT-DNS-Changer v$VERSION started"
log_info "Servers: ${#DNS_SERVERS[@]} | Check: ${HEALTH_CHECK_INTERVAL}s | Max fail: $MAX_FAILURES"

if ! start_dnstt; then
    log_error "Initial connection failed, trying next..."
    switch_to_next
    start_dnstt
fi

while $RUNNING; do
    sleep "$HEALTH_CHECK_INTERVAL"
    $RUNNING || break
    if health_check; then
        if [ $FAILURE_COUNT -gt 0 ]; then
            log_info "Connection recovered after $FAILURE_COUNT failures"
        fi
        FAILURE_COUNT=0
    else
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        log_warn "Failure $FAILURE_COUNT/$MAX_FAILURES on ${DNS_SERVERS[$CURRENT_INDEX]}"
        if [ $FAILURE_COUNT -ge $MAX_FAILURES ]; then
            log_error "Server ${DNS_SERVERS[$CURRENT_INDEX]} down!"
            FULL_ROUND=0
            ATTEMPTS=0
            while $RUNNING; do
                switch_to_next
                if start_dnstt; then
                    sleep 5
                    if kill -0 $CHILD_PID 2>/dev/null; then
                        log_info "Connected to ${DNS_SERVERS[$CURRENT_INDEX]}"
                        FAILURE_COUNT=0
                        break
                    fi
                fi
                ATTEMPTS=$((ATTEMPTS + 1))
                if [ $ATTEMPTS -ge ${#DNS_SERVERS[@]} ]; then
                    FULL_ROUND=$((FULL_ROUND + 1))
                    log_error "All servers failed! Round $FULL_ROUND. Waiting ${ALL_FAILED_WAIT}s..."
                    sleep "$ALL_FAILED_WAIT"
                    ATTEMPTS=0
                    [ $FULL_ROUND -ge 3 ] && { log_error "Waiting 60s..."; sleep 60; }
                fi
            done
        fi
    fi
done
