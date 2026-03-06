#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer Failover Engine
# https://github.com/Win-Net/dnstt-DNS-changer
# ═══════════════════════════════════════════════════════════

CONFIG_FILE="/etc/dnstt-DNS-changer/config.conf"
VERSION="1.0.0"

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
LOG_TAG="dnstt-DNS-changer"

log_info()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]    $1"; logger -t "$LOG_TAG" "INFO: $1"; }
log_warn()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1"; logger -t "$LOG_TAG" "WARNING: $1"; }
log_error()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]   $1"; logger -t "$LOG_TAG" "ERROR: $1"; }
log_switch() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SWITCH]  $1"; logger -t "$LOG_TAG" "SWITCH: $1"; }

cleanup() {
    RUNNING=false
    log_info "Shutting down..."
    if [ $CHILD_PID -ne 0 ] && kill -0 $CHILD_PID 2>/dev/null; then
        kill -TERM $CHILD_PID 2>/dev/null
        wait $CHILD_PID 2>/dev/null
    fi
    log_info "Stopped. Total switches: $TOTAL_SWITCHES"
    exit 0
}
trap cleanup SIGTERM SIGINT SIGHUP

start_dnstt() {
    local dns="${DNS_SERVERS[$CURRENT_INDEX]}"
    local domain="${DOMAINS[$CURRENT_INDEX]}"
    log_info "========================================"
    log_info "Connecting [$((CURRENT_INDEX+1))/${#DNS_SERVERS[@]}]"
    log_info "DNS: $dns | Domain: $domain | Protocol: $PROTOCOL"
    log_info "========================================"
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
        return 1
    fi
    log_info "Started (PID: $CHILD_PID)"
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
    if [ $CHILD_PID -ne 0 ] && kill -0 $CHILD_PID 2>/dev/null; then
        kill -TERM $CHILD_PID 2>/dev/null
        sleep 1
        kill -0 $CHILD_PID 2>/dev/null && kill -9 $CHILD_PID 2>/dev/null
        wait $CHILD_PID 2>/dev/null
    fi
    CURRENT_INDEX=$(( (CURRENT_INDEX + 1) % ${#DNS_SERVERS[@]} ))
    TOTAL_SWITCHES=$((TOTAL_SWITCHES + 1))
    log_switch "Changed: $old -> ${DNS_SERVERS[$CURRENT_INDEX]} (Switch #$TOTAL_SWITCHES)"
    sleep 2
}

log_info "DNSTT-DNS-Changer v$VERSION started"
log_info "Servers: ${#DNS_SERVERS[@]} | Check: ${HEALTH_CHECK_INTERVAL}s | Max fail: $MAX_FAILURES"
start_dnstt

while $RUNNING; do
    sleep "$HEALTH_CHECK_INTERVAL"
    $RUNNING || break
    if health_check; then
        FAILURE_COUNT=0
    else
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        log_warn "Failure $FAILURE_COUNT/$MAX_FAILURES on ${DNS_SERVERS[$CURRENT_INDEX]}"
        if [ $FAILURE_COUNT -ge $MAX_FAILURES ]; then
            log_error "Server down! Switching..."
            switch_to_next
            ATTEMPTS=0
            while $RUNNING; do
                start_dnstt && break
                ATTEMPTS=$((ATTEMPTS + 1))
                if [ $ATTEMPTS -ge ${#DNS_SERVERS[@]} ]; then
                    log_error "All servers down! Waiting ${ALL_FAILED_WAIT}s..."
                    sleep "$ALL_FAILED_WAIT"
                    ATTEMPTS=0
                fi
                switch_to_next
            done
        fi
    fi
done
