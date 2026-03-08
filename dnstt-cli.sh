#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer CLI (winnet-dnstt) v1.9.1
# https://github.com/Win-Net/dnstt-DNS-changer
# ═══════════════════════════════════════════════════════════

VERSION="1.9.1"
SERVICE_NAME="dnstt-DNS-changer"
CONFIG_FILE="/etc/dnstt-DNS-changer/config.conf"
REPO="https://raw.githubusercontent.com/Win-Net/dnstt-DNS-changer/main"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
PURPLE='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'
GRAY='\033[0;90m'; NC='\033[0m'; BOLD='\033[1m'

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
)

check_root() { [ "$EUID" -ne 0 ] && { echo -e "${RED}Run as root!${NC}"; exit 1; }; }

show_banner() {
    clear
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════════════════╗"
    echo "  ║                                                       ║"
    echo "  ║       ██████╗ ███╗   ██╗███████╗████████╗████████╗    ║"
    echo "  ║       ██╔══██╗████╗  ██║██╔════╝╚══██╔══╝╚══██╔══╝   ║"
    echo "  ║       ██║  ██║██╔██╗ ██║███████╗   ██║      ██║      ║"
    echo "  ║       ██║  ██║██║╚██╗██║╚════██║   ██║      ██║      ║"
    echo "  ║       ██████╔╝██║ ╚████║███████║   ██║      ██║      ║"
    echo "  ║       ╚═════╝ ╚═╝  ╚═══╝╚══════╝   ╚═╝      ╚═╝     ║"
    echo "  ║              DNS-CHANGER                              ║"
    echo "  ║                                                       ║"
    echo "  ╠═══════════════════════════════════════════════════════╣"
    echo -e "  ║  ${WHITE}Version: ${GREEN}$VERSION${CYAN}          ${WHITE}By: ${GREEN}github.com/Win-Net${CYAN}   ║"
    echo "  ╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

get_status() { systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null && echo "active" || echo "inactive"; }
load_config() { DNS_SERVERS=(); DOMAINS=(); [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"; }
count_dnstt() { local c; c=$(ps aux 2>/dev/null | grep -v grep | grep -c "dnstt-client" 2>/dev/null) || c=0; echo "$c"; }

show_status_bar() {
    local s=$(get_status)
    [ "$s" = "active" ] && echo -e "  ${WHITE}Service: ${GREEN}● RUNNING${NC}" || echo -e "  ${WHITE}Service: ${RED}● STOPPED${NC}"
    [ ! -f "/root/dnstt-client-linux-amd64" ] && echo -e "  ${RED}⚠ Missing: /root/dnstt-client-linux-amd64${NC}"
    [ ! -f "/root/pub.key" ] && echo -e "  ${RED}⚠ Missing: /root/pub.key${NC}"
    local dc=$(count_dnstt)
    [ "$dc" -gt 0 ] 2>/dev/null && echo -e "  ${WHITE}DNSTT: ${GREEN}$dc process(es)${NC}" || echo -e "  ${WHITE}DNSTT: ${RED}no process${NC}"
    load_config
    local as=${AUTO_SCAN_ENABLED:-false}
    [ "$as" = "true" ] && echo -e "  ${WHITE}Auto-Scan: ${GREEN}● ON${NC} (${AUTO_SCAN_COUNT:-30} DNS, trigger at ${AUTO_SCAN_TRIGGER:-2} left)" || echo -e "  ${WHITE}Auto-Scan: ${RED}● OFF${NC}"
    echo -e "  ${GRAY}─────────────────────────────────────────────────────${NC}"
    echo ""
}

show_menu() {
    echo -e "  ${WHITE}${BOLD}Menu:${NC}"
    echo ""
    echo -e "  ${CYAN}[${WHITE}1${CYAN}]${NC}   Service Status"
    echo -e "  ${CYAN}[${WHITE}2${CYAN}]${NC}   Start Service"
    echo -e "  ${CYAN}[${WHITE}3${CYAN}]${NC}   Stop Service"
    echo -e "  ${CYAN}[${WHITE}4${CYAN}]${NC}   Restart Service"
    echo -e "  ${CYAN}[${WHITE}5${CYAN}]${NC}   View Live Logs"
    echo -e "  ${CYAN}[${WHITE}6${CYAN}]${NC}   Switch History"
    echo -e "  ${CYAN}[${WHITE}7${CYAN}]${NC}   Edit Config"
    echo -e "  ${CYAN}[${WHITE}8${CYAN}]${NC}   Test Connection"
    echo -e "  ${CYAN}[${WHITE}9${CYAN}]${NC}   Show Config"
    echo -e "  ${CYAN}[${WHITE}10${CYAN}]${NC}  Add DNS Servers"
    echo -e "  ${CYAN}[${WHITE}11${CYAN}]${NC}  Remove DNS Server"
    echo -e "  ${CYAN}[${WHITE}12${CYAN}]${NC}  Scan & Add DNS"
    echo -e "  ${CYAN}[${WHITE}13${CYAN}]${NC}  Auto-Scan Settings"
    echo -e "  ${CYAN}[${WHITE}14${CYAN}]${NC}  Update Script"
    echo -e "  ${CYAN}[${WHITE}15${CYAN}]${NC}  Uninstall"
    echo -e "  ${CYAN}[${WHITE}0${CYAN}]${NC}   Exit"
    echo ""
    echo -e "  ${GRAY}─────────────────────────────────────────────────────${NC}"
    echo -ne "  ${WHITE}Select: ${CYAN}"
}

save_config() {
    cat > "$CONFIG_FILE" << EOF
# DNSTT-DNS-Changer Config v1.9.1 - $(date)
DNS_SERVERS=(
$(for s in "${DNS_SERVERS[@]}"; do echo "    \"$s\""; done)
)
DOMAINS=(
$(for d in "${DOMAINS[@]}"; do echo "    \"$d\""; done)
)
BINARY="${BINARY:-/root/dnstt-client-linux-amd64}"
PUBKEY_FILE="${PUBKEY_FILE:-/root/pub.key}"
LOCAL_LISTEN="${LOCAL_LISTEN:-127.0.0.1:1080}"
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
AUTO_SCAN_DOMAIN="${AUTO_SCAN_DOMAIN:-}"
AUTO_SCAN_PORT=${AUTO_SCAN_PORT:-53}
EOF
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
    local r
    r=$(timeout 3 dig @"$ip" google.com A +short +time=2 +tries=1 2>/dev/null)
    if [ -n "$r" ] && echo "$r" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; then
        local r2
        r2=$(timeout 3 dig @"$ip" cloudflare.com A +short +time=2 +tries=1 2>/dev/null)
        if [ -n "$r2" ] && echo "$r2" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; then
            return 0
        fi
    fi
    return 1
}

full_stop() { systemctl stop "$SERVICE_NAME" 2>/dev/null; pkill -9 -f "dnstt-client" 2>/dev/null; sleep 2; }
full_start() { chmod +x /root/dnstt-client-linux-amd64 2>/dev/null; systemctl start "$SERVICE_NAME" 2>/dev/null; sleep 5; }

opt_status() {
    show_banner; echo -e "  ${WHITE}${BOLD}=== Status ===${NC}"; echo ""
    [ -f "/root/dnstt-client-linux-amd64" ] && echo -e "  ${GREEN}✓ dnstt-client${NC}" || echo -e "  ${RED}✗ dnstt-client${NC}"
    [ -f "/root/pub.key" ] && echo -e "  ${GREEN}✓ pub.key${NC}" || echo -e "  ${RED}✗ pub.key${NC}"
    echo ""
    if [ "$(get_status)" = "active" ]; then
        echo -e "  ${GREEN}● RUNNING${NC}"
        local pid=$(systemctl show -p MainPID "$SERVICE_NAME" | cut -d= -f2)
        [ "$pid" != "0" ] && echo -e "  PID:    $pid"
        local up=$(ps -o etime= -p "$pid" 2>/dev/null | xargs); [ -n "$up" ] && echo -e "  Uptime: $up"
        load_config; echo -e "  SOCKS5: ${LOCAL_LISTEN}"; echo -e "  DNS:    ${#DNS_SERVERS[@]} servers"
        echo -e "  DNSTT:  $(count_dnstt) process(es)"
    else echo -e "  ${RED}● STOPPED${NC}"; fi
    echo ""; systemctl status "$SERVICE_NAME" --no-pager -l 2>/dev/null | head -15 | sed 's/^/  /'
    echo ""; read -p "  Press Enter..."
}

opt_start() {
    show_banner
    [ ! -f "/root/dnstt-client-linux-amd64" ] || [ ! -f "/root/pub.key" ] && { echo -e "  ${RED}Missing files!${NC}"; read -p "  Press Enter..."; return; }
    echo -e "  ${YELLOW}Starting...${NC}"; full_start
    [ "$(get_status)" = "active" ] && echo -e "  ${GREEN}✓${NC}" || echo -e "  ${RED}✗${NC}"
    echo ""; read -p "  Press Enter..."
}

opt_stop() { show_banner; echo -e "  ${YELLOW}Stopping...${NC}"; full_stop; echo -e "  ${GREEN}✓${NC}"; echo ""; read -p "  Press Enter..."; }

opt_restart() {
    show_banner; echo -e "  ${YELLOW}Restarting...${NC}"; full_stop; full_start
    [ "$(get_status)" = "active" ] && echo -e "  ${GREEN}✓${NC}" || echo -e "  ${RED}✗${NC}"
    echo ""; read -p "  Press Enter..."
}

opt_logs() {
    show_banner; echo -e "  ${WHITE}=== Logs ===${NC} ${GRAY}(Ctrl+C)${NC}"; echo ""
    journalctl -u "$SERVICE_NAME" -f --no-pager 2>/dev/null | while IFS= read -r line; do
        if echo "$line" | grep -q "ERROR"; then echo -e "  ${RED}$line${NC}"
        elif echo "$line" | grep -q "SWITCH"; then echo -e "  ${PURPLE}$line${NC}"
        elif echo "$line" | grep -q "SCAN"; then echo -e "  ${CYAN}$line${NC}"
        elif echo "$line" | grep -q "WARNING"; then echo -e "  ${YELLOW}$line${NC}"
        else echo -e "  ${GREEN}$line${NC}"; fi
    done
}

opt_history() {
    show_banner; echo -e "  ${WHITE}=== History ===${NC}"; echo ""
    journalctl -u "$SERVICE_NAME" --no-pager 2>/dev/null | grep -E "SWITCH|SCAN|Connected|ALL.*failed" | tail -40 | sed 's/^/  /'
    echo ""; read -p "  Press Enter..."
}

opt_edit() {
    local ed="nano"; command -v nano &>/dev/null || ed="vi"; $ed "$CONFIG_FILE"
    echo -ne "  ${YELLOW}Restart? (y/n): ${NC}"; read -r a
    [ "$a" = "y" ] && { full_stop; full_start; echo -e "  ${GREEN}✓${NC}"; }
    read -p "  Press Enter..."
}

opt_test() {
    show_banner; echo -e "  ${WHITE}=== Test ===${NC}"; echo ""; load_config
    echo -ne "  Service: "; [ "$(get_status)" = "active" ] && echo -e "${GREEN}✓${NC}" || { echo -e "${RED}✗${NC}"; read -p "  Press Enter..."; return; }
    local port="${LOCAL_LISTEN##*:}"
    echo -ne "  Port:    "; ss -tlnp 2>/dev/null | grep -q ":${port}" && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
    echo -ne "  SOCKS:   "
    if timeout 15 curl -s --socks5 "$LOCAL_LISTEN" "http://httpbin.org/ip" -o /tmp/dt 2>/dev/null; then
        echo -e "${GREEN}✓ $(cat /tmp/dt 2>/dev/null)${NC}"; else echo -e "${RED}✗${NC}"; fi; rm -f /tmp/dt
    echo ""; echo -e "  ${WHITE}DNS Servers (${#DNS_SERVERS[@]}):${NC}"
    for i in "${!DNS_SERVERS[@]}"; do echo "    [$((i+1))] ${DNS_SERVERS[$i]} -> ${DOMAINS[$i]}"; done
    echo ""; read -p "  Press Enter..."
}

opt_showconf() { show_banner; echo -e "  ${WHITE}=== Config ===${NC}"; echo ""; cat "$CONFIG_FILE" | sed 's/^/  /'; echo ""; read -p "  Press Enter..."; }

opt_add_dns() {
    show_banner; echo -e "  ${WHITE}=== Add DNS ===${NC}"; echo ""; load_config
    [ ${#DNS_SERVERS[@]} -gt 0 ] && { for i in "${!DNS_SERVERS[@]}"; do echo "    [$((i+1))] ${DNS_SERVERS[$i]}"; done; echo ""; }
    echo -e "  ${CYAN}Empty = done:${NC}"; echo ""; local added=0 num=$((${#DNS_SERVERS[@]}+1))
    while true; do
        echo -ne "  Server $num (ip:port): "; read -r nd; [ -z "$nd" ] && break
        echo -ne "  Domain: "; read -r nm; [ -z "$nm" ] && { echo -e "  ${RED}Need domain!${NC}"; continue; }
        DNS_SERVERS+=("$nd"); DOMAINS+=("$nm"); added=$((added+1)); num=$((num+1)); echo -e "  ${GREEN}✓${NC}"; echo ""
    done
    if [ $added -gt 0 ]; then
        save_config; echo -e "  ${GREEN}✓ $added added (total: ${#DNS_SERVERS[@]})${NC}"
        echo -ne "  ${YELLOW}Restart? (y/n): ${NC}"; read -r r; [ "$r" = "y" ] && { full_stop; full_start; echo -e "  ${GREEN}✓${NC}"; }
    fi; read -p "  Press Enter..."
}

opt_remove_dns() {
    show_banner; echo -e "  ${WHITE}=== Remove DNS ===${NC}"; echo ""; load_config
    [ ${#DNS_SERVERS[@]} -le 1 ] && { echo -e "  ${RED}Need at least 1!${NC}"; read -p "  Press Enter..."; return; }
    for i in "${!DNS_SERVERS[@]}"; do echo "    [$((i+1))] ${DNS_SERVERS[$i]}"; done
    echo ""; echo -ne "  Remove # (0=cancel): "; read -r rn
    [ -z "$rn" ] || [ "$rn" = "0" ] && { read -p "  Press Enter..."; return; }
    [[ ! "$rn" =~ ^[0-9]+$ ]] && { echo -e "  ${RED}Invalid${NC}"; read -p "  Press Enter..."; return; }
    local idx=$((rn-1))
    [ $idx -lt 0 ] || [ $idx -ge ${#DNS_SERVERS[@]} ] && { echo -e "  ${RED}Invalid${NC}"; read -p "  Press Enter..."; return; }
    echo -ne "  ${RED}Remove ${DNS_SERVERS[$idx]}? (y/n): ${NC}"; read -r cf; [ "$cf" != "y" ] && { read -p "  Press Enter..."; return; }
    local td=() tm=()
    for i in "${!DNS_SERVERS[@]}"; do [ "$i" -ne "$idx" ] && { td+=("${DNS_SERVERS[$i]}"); tm+=("${DOMAINS[$i]}"); }; done
    DNS_SERVERS=("${td[@]}"); DOMAINS=("${tm[@]}"); save_config
    echo -e "  ${GREEN}✓ (${#DNS_SERVERS[@]} left)${NC}"
    echo -ne "  ${YELLOW}Restart? (y/n): ${NC}"; read -r r; [ "$r" = "y" ] && { full_stop; full_start; }
    read -p "  Press Enter..."
}

# Manual scan
opt_scan_dns() {
    show_banner; echo -e "  ${WHITE}${BOLD}=== DNS Scanner ===${NC}"; echo ""
    if ! command -v dig &>/dev/null; then
        echo -e "  ${YELLOW}Installing dig...${NC}"
        apt-get install -y -qq dnsutils 2>/dev/null || yum install -y -q bind-utils 2>/dev/null
        command -v dig &>/dev/null || { echo -e "  ${RED}Failed to install dig!${NC}"; read -p "  Press Enter..."; return; }
    fi
    echo -ne "  ${WHITE}How many DNS to find? [30]: ${NC}"; read -r st; st=${st:-30}
    echo -ne "  ${WHITE}Domain: ${NC}"; read -r sd; [ -z "$sd" ] && { echo -e "  ${RED}Required!${NC}"; read -p "  Press Enter..."; return; }
    echo -ne "  ${WHITE}Port [53]: ${NC}"; read -r sp; sp=${sp:-53}
    echo -ne "  ${WHITE}Replace or add? (replace/add) [add]: ${NC}"; read -r sm; sm=${sm:-add}
    echo ""; echo -e "  ${YELLOW}Scanning for $st DNS servers...${NC}"; echo ""

    load_config
    [ "$sm" = "replace" ] && { DNS_SERVERS=(); DOMAINS=(); }

    local found=0 tested=0 start=$(date +%s)

    # Phase 1: Known DNS list (shuffled)
    local SCAN_LIST=("${KNOWN_DNS_LIST[@]}")
    shuffle_array SCAN_LIST

    echo -e "  ${CYAN}Phase 1: Testing ${#SCAN_LIST[@]} known DNS servers...${NC}"; echo ""

    for ip in "${SCAN_LIST[@]}"; do
        [ $found -ge $st ] && break
        tested=$((tested + 1))

        # Check duplicate
        local dup=false
        for e in "${DNS_SERVERS[@]}"; do
            [ "$e" = "${ip}:${sp}" ] && { dup=true; break; }
        done
        [ "$dup" = true ] && continue

        if test_dns_server "$ip"; then
            found=$((found+1))
            DNS_SERVERS+=("${ip}:${sp}")
            DOMAINS+=("$sd")
            echo -e "  ${GREEN}[$found/$st]${NC} ${ip}:${sp} ${GRAY}(tested: $tested)${NC}"
        fi

        [ $((tested % 50)) -eq 0 ] && [ $found -lt $st ] && echo -e "  ${GRAY}... $tested tested, $found found${NC}"
    done

    # Phase 2: Random scan on known subnets
    if [ $found -lt $st ]; then
        echo ""
        echo -e "  ${CYAN}Phase 2: Random scanning known subnets (need $((st - found)) more)...${NC}"; echo ""

        local extra_tested=0
        while [ $found -lt $st ] && [ $extra_tested -lt 2000 ]; do
            local subnet="${SCAN_SUBNETS[$((RANDOM % ${#SCAN_SUBNETS[@]}))]}"
            local ip="${subnet}.$((RANDOM % 254 + 1))"
            extra_tested=$((extra_tested + 1))
            tested=$((tested + 1))

            local dup=false
            for e in "${DNS_SERVERS[@]}"; do
                [ "$e" = "${ip}:${sp}" ] && { dup=true; break; }
            done
            [ "$dup" = true ] && continue

            if test_dns_server "$ip"; then
                found=$((found+1))
                DNS_SERVERS+=("${ip}:${sp}")
                DOMAINS+=("$sd")
                echo -e "  ${GREEN}[$found/$st]${NC} ${ip}:${sp} ${GRAY}(tested: $tested, random)${NC}"
            fi

            [ $((extra_tested % 100)) -eq 0 ] && [ $found -lt $st ] && echo -e "  ${GRAY}... $tested tested, $found found${NC}"
        done
    fi

    echo ""; echo -e "  ${WHITE}Found: ${GREEN}$found${NC} | Tested: $tested | Time: $(( $(date +%s) - start ))s | Total: ${#DNS_SERVERS[@]}${NC}"
    if [ $found -gt 0 ]; then
        echo -ne "  ${WHITE}Save? (y/n): ${NC}"; read -r sv
        if [ "$sv" = "y" ]; then
            save_config; echo -e "  ${GREEN}✓ Saved${NC}"
            echo -ne "  ${YELLOW}Restart? (y/n): ${NC}"; read -r r; [ "$r" = "y" ] && { full_stop; full_start; echo -e "  ${GREEN}✓${NC}"; }
        fi
    fi; read -p "  Press Enter..."
}

# Auto-scan settings
opt_autoscan() {
    show_banner; echo -e "  ${WHITE}${BOLD}=== Auto-Scan Settings ===${NC}"; echo ""
    load_config
    local as=${AUTO_SCAN_ENABLED:-false}
    local at=${AUTO_SCAN_TRIGGER:-2}
    local ac=${AUTO_SCAN_COUNT:-30}
    local ad=${AUTO_SCAN_DOMAIN:-not set}
    local ap=${AUTO_SCAN_PORT:-53}

    echo -e "  ${WHITE}Current:${NC}"
    [ "$as" = "true" ] && echo -e "    Status:  ${GREEN}● ON${NC}" || echo -e "    Status:  ${RED}● OFF${NC}"
    echo -e "    Trigger: when all DNS fail, auto-scan new ones"
    echo -e "    Count:   ${CYAN}$ac${NC} DNS to find"
    echo -e "    Domain:  ${CYAN}$ad${NC}"
    echo -e "    Port:    ${CYAN}$ap${NC}"
    echo ""
    echo -e "    ${CYAN}[1]${NC} Toggle ON/OFF"
    echo -e "    ${CYAN}[2]${NC} Set scan count"
    echo -e "    ${CYAN}[3]${NC} Set domain"
    echo -e "    ${CYAN}[4]${NC} Set port"
    echo -e "    ${CYAN}[0]${NC} Back"
    echo ""
    echo -ne "  ${WHITE}Select: ${NC}"; read -r ch

    case $ch in
        1)
            if [ "$as" = "true" ]; then
                AUTO_SCAN_ENABLED=false; echo -e "  ${RED}Auto-Scan OFF${NC}"
            else
                AUTO_SCAN_ENABLED=true; echo -e "  ${GREEN}Auto-Scan ON${NC}"
                if [ -z "$AUTO_SCAN_DOMAIN" ] || [ "$AUTO_SCAN_DOMAIN" = "not set" ]; then
                    echo -ne "  ${WHITE}Domain for scanned DNS: ${NC}"; read -r nd
                    [ -n "$nd" ] && AUTO_SCAN_DOMAIN="$nd"
                fi
            fi
            save_config ;;
        2)
            echo -ne "  ${WHITE}How many DNS [$ac]: ${NC}"; read -r nc
            [ -n "$nc" ] && { AUTO_SCAN_COUNT=$nc; save_config; echo -e "  ${GREEN}✓ $nc${NC}"; } ;;
        3)
            echo -ne "  ${WHITE}Domain: ${NC}"; read -r nd
            [ -n "$nd" ] && { AUTO_SCAN_DOMAIN="$nd"; save_config; echo -e "  ${GREEN}✓ $nd${NC}"; } ;;
        4)
            echo -ne "  ${WHITE}Port [$ap]: ${NC}"; read -r np
            [ -n "$np" ] && { AUTO_SCAN_PORT=$np; save_config; echo -e "  ${GREEN}✓ $np${NC}"; } ;;
        0) return ;;
    esac
    echo -ne "  ${YELLOW}Restart? (y/n): ${NC}"; read -r r
    [ "$r" = "y" ] && { full_stop; full_start; echo -e "  ${GREEN}✓${NC}"; }
    read -p "  Press Enter..."
}

opt_update() {
    show_banner; echo -e "  ${WHITE}=== Update ===${NC}"
    echo -e "  Current: ${CYAN}$VERSION${NC} | Config: ${GREEN}safe${NC}"
    echo -ne "  Update? (y/n): "; read -r u; [ "$u" != "y" ] && { read -p "  Press Enter..."; return; }
    full_stop
    echo -ne "  Failover... "; curl -sL "$REPO/dnstt-failover.sh" -o /usr/local/bin/dnstt-failover && chmod +x /usr/local/bin/dnstt-failover && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
    echo -ne "  CLI...      "; curl -sL "$REPO/dnstt-cli.sh" -o /usr/local/bin/winnet-dnstt && chmod +x /usr/local/bin/winnet-dnstt && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
    cat > /etc/systemd/system/${SERVICE_NAME}.service << 'SVCEOF'
[Unit]
Description=DNSTT-DNS-Changer
After=network.target network-online.target
Wants=network-online.target
[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/local/bin/dnstt-failover
Restart=always
RestartSec=5s
StandardOutput=journal
StandardError=journal
TimeoutStopSec=10
KillMode=mixed
KillSignal=SIGTERM
SendSIGKILL=yes
[Install]
WantedBy=multi-user.target
SVCEOF
    systemctl daemon-reload; full_start
    systemctl is-active --quiet "$SERVICE_NAME" && echo -e "  ${GREEN}✓${NC}" || echo -e "  ${YELLOW}⚠${NC}"
    echo -e "  ${YELLOW}Run winnet-dnstt again${NC}"; echo ""; read -p "  Press Enter..."; exit 0
}

opt_uninstall() {
    show_banner; echo -e "  ${RED}=== Uninstall ===${NC}"
    echo -ne "  Type 'yes': "; read -r c; [ "$c" != "yes" ] && { read -p "  Press Enter..."; return; }
    full_stop; systemctl disable "$SERVICE_NAME" 2>/dev/null
    rm -f /etc/systemd/system/${SERVICE_NAME}.service /usr/local/bin/dnstt-failover /usr/local/bin/winnet-dnstt
    echo -ne "  Remove config? (y/n): "; read -r rc; [ "$rc" = "y" ] && rm -rf /etc/dnstt-DNS-changer
    systemctl daemon-reload 2>/dev/null; echo -e "  ${GREEN}✓${NC}"; exit 0
}

check_root
while true; do
    show_banner; show_status_bar; show_menu; read -r choice; echo -e "${NC}"
    case $choice in
        1) opt_status ;; 2) opt_start ;; 3) opt_stop ;; 4) opt_restart ;;
        5) opt_logs ;; 6) opt_history ;; 7) opt_edit ;; 8) opt_test ;;
        9) opt_showconf ;; 10) opt_add_dns ;; 11) opt_remove_dns ;;
        12) opt_scan_dns ;; 13) opt_autoscan ;; 14) opt_update ;; 15) opt_uninstall ;;
        0) echo -e "  ${GREEN}Bye!${NC}"; exit 0 ;;
        *) echo -e "  ${RED}Invalid!${NC}"; sleep 1 ;;
    esac
done
