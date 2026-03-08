#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer v1.9.2 - With Auto-Scan (Iran Compatible)
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

KNOWN_DNS_LIST=(
    "1.1.1.1" "1.0.0.1" "1.1.1.2" "1.0.0.2" "1.1.1.3" "1.0.0.3"
    "8.8.8.8" "8.8.4.4"
    "9.9.9.9" "9.9.9.10" "9.9.9.11" "9.9.9.12"
    "149.112.112.112" "149.112.112.11" "149.112.112.12"
    "208.67.222.222" "208.67.220.220" "208.67.222.123" "208.67.220.123"
    "8.26.56.26" "8.20.247.20"
    "209.244.0.3" "209.244.0.4"
    "64.6.64.6" "64.6.65.6"
    "84.200.69.80" "84.200.70.40"
    "156.154.70.1" "156.154.71.1" "156.154.70.2" "156.154.71.2"
    "156.154.70.3" "156.154.71.3" "156.154.70.4" "156.154.71.4"
    "156.154.70.5" "156.154.71.5"
    "195.46.39.39" "195.46.39.40"
    "216.146.35.35" "216.146.36.36"
    "37.235.1.174" "37.235.1.177"
    "76.76.19.19" "76.223.122.150"
    "94.140.14.14" "94.140.15.15" "94.140.14.15" "94.140.15.16"
    "94.140.14.140" "94.140.14.141"
    "185.228.168.9" "185.228.169.9" "185.228.168.168" "185.228.169.168"
    "185.228.168.10" "185.228.169.11"
    "77.88.8.8" "77.88.8.1" "77.88.8.88" "77.88.8.2" "77.88.8.7" "77.88.8.3"
    "114.114.114.114" "114.114.115.115" "114.114.114.119" "114.114.115.119"
    "1.2.4.8" "210.2.4.8"
    "194.242.2.2" "194.242.2.3" "194.242.2.4" "194.242.2.5" "194.242.2.9"
    "45.90.28.0" "45.90.30.0" "45.90.28.167" "45.90.30.167"
    "76.76.2.0" "76.76.10.0" "76.76.2.1" "76.76.10.1"
    "76.76.2.2" "76.76.10.2" "76.76.2.3" "76.76.10.3"
    "76.76.2.4" "76.76.10.4" "76.76.2.5" "76.76.10.5"
    "88.198.92.222"
    "185.222.222.222" "45.11.45.11"
    "5.2.75.75"
    "91.239.100.100" "89.233.43.71"
    "185.12.64.1" "185.12.64.2"
    "109.69.8.51"
    "146.255.56.98"
    "149.112.121.10" "149.112.122.10" "149.112.121.20" "149.112.122.20"
    "149.112.121.30" "149.112.122.30"
    "193.58.251.251"
    "104.155.237.225" "104.197.28.121"
    "180.131.144.144" "180.131.145.145"
    "193.17.47.1" "193.17.47.15"
    "74.82.42.42"
    "62.210.16.6"
    "172.104.237.57" "185.121.177.177"
    "178.79.131.110" "176.9.37.132"
    "176.9.93.198" "176.103.130.130" "176.103.130.131"
    "158.64.1.29"
    "80.67.169.12" "80.67.169.40"
    "185.43.135.1"
    "101.101.101.101" "101.102.103.104"
    "168.95.1.1" "168.95.192.1"
    "223.5.5.5" "223.6.6.6"
    "119.29.29.29" "119.28.28.28"
    "180.76.76.76"
    "117.50.10.10" "117.50.20.20"
    "101.226.4.6" "218.30.118.6"
    "168.126.63.1" "168.126.63.2"
    "164.124.101.2" "203.248.252.2"
    "210.220.163.82" "219.250.36.130"
    "129.250.35.250" "129.250.35.251"
    "210.130.0.1" "210.130.1.1"
    "203.178.136.1"
    "204.117.214.10" "199.2.252.10"
    "46.182.19.48"
    "80.80.80.80" "80.80.81.81"
    "85.214.20.141"
    "78.46.244.143"
    "159.69.198.101"
    "116.202.176.26"
    "116.203.70.156"
    "51.15.98.97"
    "139.59.48.222"
    "188.166.18.30"
    "159.89.120.99"
    "134.195.4.2"
    "136.144.215.158"
    "139.162.112.47"
    "107.150.40.234"
    "108.61.201.119"
    "198.101.242.72"
    "207.148.83.241"
    "104.236.210.29"
    "45.33.32.156"
    "66.70.228.164"
    "103.86.96.100" "103.86.99.100"
    "199.85.126.10" "199.85.127.10"
    "203.67.25.110"
    "203.198.7.66"
    "217.160.70.42"
    "4.2.2.1" "4.2.2.2" "4.2.2.3" "4.2.2.4" "4.2.2.5" "4.2.2.6"
    "205.171.3.65" "205.171.2.65"
    "198.153.192.1" "198.153.194.1"
    "208.76.50.50" "208.76.51.51"
    "216.87.84.211"
    "23.253.163.53"
    "199.255.137.34"
    "208.69.38.205" "208.69.39.205"
    "91.217.137.37"
    "65.110.131.133" "65.110.131.134"
    "209.51.161.58"
    "199.249.148.1"
    "169.239.202.202"
    "196.46.173.196"
    "41.58.188.34"
    "102.134.96.1"
    "197.234.240.1"
    "41.203.197.12"
    "154.70.1.1"
    "105.235.100.100"
    "41.211.233.9"
    "110.232.176.19"
    "202.46.34.75" "202.46.34.76"
    "202.136.162.11"
    "61.8.0.113"
    "202.134.0.155"
    "202.62.2.24" "202.62.2.25"
    "103.228.184.1"
    "103.247.36.36"
    "200.1.123.46"
    "200.0.11.11"
    "190.232.33.32"
    "200.95.144.3" "200.95.144.4"
    "200.115.192.12"
    "200.221.11.100" "200.221.11.101"
    "69.10.33.10" "69.10.44.10"
    "68.94.156.1" "68.94.157.1"
    "205.152.37.23"
    "205.134.202.146"
    "50.116.23.211"
    "66.244.95.20"
    "96.90.175.167"
    "38.132.106.168"
    "174.138.21.128"
    "5.1.66.255"
    "82.141.39.32"
    "50.0.0.1" "50.0.0.2"
    "198.54.117.10" "198.54.117.11"
    "199.5.157.131"
    "208.43.71.1"
    "72.14.189.120"
    "119.18.152.3" "119.18.152.5"
    "202.56.250.36" "202.56.250.37"
    "203.115.81.30" "203.115.81.35"
    "121.29.36.1" "121.29.36.3"
    "202.45.84.58"
    "218.248.241.3"
    "115.68.100.100" "115.68.100.200"
    "202.248.37.74"
    "202.12.27.33"
    "160.16.59.181"
    "175.100.54.30"
    "202.83.20.101"
    "202.14.67.4" "202.14.67.14"
    "123.108.8.8"
    "202.188.0.133" "202.188.1.5"
    "2.144.4.202" "10.202.10.10" "10.202.10.11"
    "178.22.122.100" "185.51.200.2"
    "78.157.42.100" "78.157.42.101"
    "185.55.225.25" "185.55.226.26"
    "217.218.155.155" "217.218.127.127"
    "185.231.182.126" "185.231.182.162"
    "78.158.171.6" "78.158.171.7"
    "5.202.100.100" "5.202.100.101"
    "10.202.10.202" "10.202.10.102"
    "85.15.1.14" "85.15.1.15"
    "31.7.57.18" "31.7.57.26"
    "5.160.139.199" "5.160.139.200"
    "91.92.22.50" "91.92.22.51"
    "185.136.170.170" "185.136.171.171"
    "46.224.1.42" "46.224.1.43"
    "188.229.237.1" "188.229.237.2"
    "5.144.132.1" "5.144.132.2"
    "91.99.101.14" "91.99.101.15"
    "5.63.0.151" "5.63.0.152"
    "185.105.187.237" "185.105.187.238"
    "185.171.23.10" "185.171.23.11"
    "79.175.131.4" "79.175.131.5"
    "94.232.173.130" "94.232.173.131"
    "5.200.200.200" "5.200.200.201"
    "185.37.35.4" "185.37.35.5"
    "194.36.174.161" "194.36.174.162"
    "95.156.233.22" "95.156.233.23"
    "193.19.227.10" "193.19.227.11"
    "5.232.115.10" "5.232.115.11"
    "109.122.240.81" "109.122.240.82"
    "2.188.20.10" "2.188.20.11"
    "2.178.12.10" "2.178.12.11"
    "5.56.132.56" "5.56.133.56"
    "151.232.97.14" "151.232.97.15"
    "80.191.56.14" "80.191.56.15"
    "92.50.4.14" "92.50.4.15"
    "37.152.176.14" "37.152.176.15"
    "37.156.28.10" "37.156.28.11"
    "185.128.80.10" "185.128.80.11"
    "5.145.112.14" "5.145.112.15"
    "79.127.127.11" "79.127.127.12"
    "91.92.208.136" "91.92.208.137"
    "5.253.27.14" "5.253.27.15"
    "176.65.176.14" "176.65.176.15"
    "93.119.210.14" "93.119.210.15"
    "37.156.145.14" "37.156.145.15"
    "2.146.0.14" "2.146.0.15"
    "185.208.78.14" "185.208.78.15"
    "188.0.240.14" "188.0.240.15"
    "5.253.24.14" "5.253.24.15"
)

SCAN_SUBNETS=(
    "1.0.0" "1.1.1" "8.8.8" "8.8.4" "9.9.9"
    "208.67.222" "208.67.220" "149.112.112"
    "94.140.14" "94.140.15"
    "185.228.168" "185.228.169"
    "76.76.2" "76.76.10" "76.76.19"
    "45.90.28" "45.90.30"
    "156.154.70" "156.154.71"
    "223.5.5" "223.6.6"
    "119.29.29" "119.28.28"
    "176.103.130"
    "185.222.222"
    "194.242.2"
    "101.101.101"
    "168.95.1" "168.95.192"
    "114.114.114" "114.114.115"
    "77.88.8"
    "195.46.39"
    "84.200.69" "84.200.70"
    "185.12.64"
    "185.43.135"
    "103.86.96" "103.86.99"
    "199.85.126" "199.85.127"
    "129.250.35"
    "210.130.0" "210.130.1"
    "178.22.122" "185.51.200"
    "78.157.42" "185.55.225" "185.55.226"
    "217.218.155" "217.218.127"
    "185.231.182" "78.158.171"
    "5.202.100" "85.15.1"
    "31.7.57" "5.160.139"
    "91.92.22" "185.136.170" "185.136.171"
    "46.224.1" "188.229.237"
    "5.144.132" "91.99.101"
    "5.63.0" "185.105.187"
    "185.171.23" "79.175.131"
    "94.232.173" "5.200.200"
    "185.37.35" "194.36.174"
    "2.144.4" "10.202.10"
)

SCAN_TEST_DOMAINS=(
    "google.com"
    "cloudflare.com"
    "microsoft.com"
    "apple.com"
    "amazon.com"
    "facebook.com"
    "twitter.com"
    "youtube.com"
    "instagram.com"
    "wikipedia.org"
    "yahoo.com"
    "linkedin.com"
    "netflix.com"
    "reddit.com"
    "whatsapp.com"
    "github.com"
    "stackoverflow.com"
    "digikala.com"
    "aparat.com"
    "varzesh3.com"
    "namnak.com"
    "telewebion.com"
    "shaparak.ir"
    "tsetmc.com"
    "bmi.ir"
    "irancell.ir"
    "mci.ir"
    "snapp.ir"
)

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

shuffle_array() {
    local -n arr=$1
    local n=${#arr[@]}
    for ((i = n - 1; i > 0; i--)); do
        local j=$((RANDOM % (i + 1)))
        local tmp="${arr[$i]}"
        arr[$i]="${arr[$j]}"
        arr[$j]="$tmp"
    done
}

test_dns_server() {
    local ip="$1"
    local test_domain="${SCAN_TEST_DOMAINS[$((RANDOM % ${#SCAN_TEST_DOMAINS[@]}))]}"
    local test_domain2="${SCAN_TEST_DOMAINS[$((RANDOM % ${#SCAN_TEST_DOMAINS[@]}))]}"

    local r
    r=$(timeout 5 dig @"$ip" "$test_domain" A +short +time=3 +tries=1 2>/dev/null)
    if [ -n "$r" ] && echo "$r" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; then
        local r2
        r2=$(timeout 5 dig @"$ip" "$test_domain2" A +short +time=3 +tries=1 2>/dev/null)
        if [ -n "$r2" ] && echo "$r2" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; then
            return 0
        fi
    fi
    return 1
}

save_config_file() {
    cat > "$CONFIG_FILE" << SCANEOF
# DNSTT-DNS-Changer Config - Updated $(date)
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
}

auto_scan() {
    source "$CONFIG_FILE" 2>/dev/null
    local scan_on=${AUTO_SCAN_ENABLED:-false}
    [ "$scan_on" != "true" ] && return

    local scan_count=${AUTO_SCAN_COUNT:-30}
    local scan_domain=${AUTO_SCAN_DOMAIN:-}
    local scan_port=${AUTO_SCAN_PORT:-53}

    [ -z "$scan_domain" ] && return

    if ! command -v dig &>/dev/null; then
        log "WARNING" "dig not installed, installing..."
        apt-get install -y -qq dnsutils 2>/dev/null || yum install -y -q bind-utils 2>/dev/null
        if ! command -v dig &>/dev/null; then
            log "ERROR" "Cannot install dig, aborting scan"
            return
        fi
    fi

    log "INFO" "AUTO-SCAN: Starting scan for $scan_count DNS servers"

    local SCAN_LIST=("${KNOWN_DNS_LIST[@]}")
    shuffle_array SCAN_LIST

    local new_dns=()
    local new_domains=()
    local found=0
    local tested=0

    # Phase 1: Test known DNS servers
    log "INFO" "AUTO-SCAN: Phase 1 - Testing ${#SCAN_LIST[@]} known DNS servers"

    for ip in "${SCAN_LIST[@]}"; do
        [ $found -ge $scan_count ] && break
        tested=$((tested + 1))

        if [ $((tested % 50)) -eq 0 ]; then
            log "INFO" "AUTO-SCAN: Progress: tested=$tested found=$found"
        fi

        local dup=false
        for e in "${new_dns[@]}"; do
            [ "$e" = "${ip}:${scan_port}" ] && { dup=true; break; }
        done
        [ "$dup" = true ] && continue

        if test_dns_server "$ip"; then
            found=$((found + 1))
            new_dns+=("${ip}:${scan_port}")
            new_domains+=("$scan_domain")
            log "INFO" "AUTO-SCAN: [$found/$scan_count] Found ${ip}:${scan_port}"
        fi
    done

    # Phase 2: Random scan on known DNS subnets
    if [ $found -lt $scan_count ]; then
        log "INFO" "AUTO-SCAN: Phase 2 - Random scanning (need $((scan_count - found)) more)"

        local extra_tested=0
        while [ $found -lt $scan_count ] && [ $extra_tested -lt 2000 ]; do
            local subnet="${SCAN_SUBNETS[$((RANDOM % ${#SCAN_SUBNETS[@]}))]}"
            local ip="${subnet}.$((RANDOM % 254 + 1))"
            extra_tested=$((extra_tested + 1))

            local dup=false
            for e in "${new_dns[@]}"; do
                [ "$e" = "${ip}:${scan_port}" ] && { dup=true; break; }
            done
            [ "$dup" = true ] && continue

            if test_dns_server "$ip"; then
                found=$((found + 1))
                new_dns+=("${ip}:${scan_port}")
                new_domains+=("$scan_domain")
                log "INFO" "AUTO-SCAN: [$found/$scan_count] Found ${ip}:${scan_port} (random)"
            fi
        done
    fi

    if [ $found -gt 0 ]; then
        DNS_SERVERS=("${new_dns[@]}")
        DOMAINS=("${new_domains[@]}")
        TOTAL=${#DNS_SERVERS[@]}
        IDX=0
        save_config_file
        log "INFO" "AUTO-SCAN: Complete! Found $found DNS servers, config updated"
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

    source "$CONFIG_FILE" 2>/dev/null
    local scan_on=${AUTO_SCAN_ENABLED:-false}

    if [ "$scan_on" = "true" ]; then
        log "INFO" "AUTO-SCAN triggered: all servers down"
        auto_scan

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

# MAIN
log "INFO" "v1.9.2 | Servers=$TOTAL | Check=${CHECK}s | MaxFail=$MAX_FAIL"

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
