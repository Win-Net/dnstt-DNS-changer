#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer CLI (winnet-dnstt) v1.8.0
# https://github.com/Win-Net/dnstt-DNS-changer
# ═══════════════════════════════════════════════════════════

VERSION="1.8.0"
SERVICE_NAME="dnstt-DNS-changer"
CONFIG_FILE="/etc/dnstt-DNS-changer/config.conf"
REPO="https://raw.githubusercontent.com/Win-Net/dnstt-DNS-changer/main"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
PURPLE='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'
GRAY='\033[0;90m'; NC='\033[0m'; BOLD='\033[1m'

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

load_config() {
    DNS_SERVERS=(); DOMAINS=()
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
}

count_dnstt() {
    local c
    c=$(ps aux 2>/dev/null | grep -v grep | grep -c "dnstt-client" 2>/dev/null) || c=0
    echo "$c"
}

show_status_bar() {
    local s=$(get_status)
    [ "$s" = "active" ] && echo -e "  ${WHITE}Service: ${GREEN}● RUNNING${NC}" || echo -e "  ${WHITE}Service: ${RED}● STOPPED${NC}"
    [ ! -f "/root/dnstt-client-linux-amd64" ] && echo -e "  ${RED}⚠ Missing: /root/dnstt-client-linux-amd64${NC}"
    [ ! -f "/root/pub.key" ] && echo -e "  ${RED}⚠ Missing: /root/pub.key${NC}"
    local dc=$(count_dnstt)
    if [ "$dc" -gt 0 ] 2>/dev/null; then
        echo -e "  ${WHITE}DNSTT: ${GREEN}$dc process(es) active${NC}"
    else
        echo -e "  ${WHITE}DNSTT: ${RED}no process${NC}"
    fi
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
    echo -e "  ${CYAN}[${WHITE}6${CYAN}]${NC}   Switch & Restart History"
    echo -e "  ${CYAN}[${WHITE}7${CYAN}]${NC}   Edit Config"
    echo -e "  ${CYAN}[${WHITE}8${CYAN}]${NC}   Test Connection"
    echo -e "  ${CYAN}[${WHITE}9${CYAN}]${NC}   Show Config"
    echo -e "  ${CYAN}[${WHITE}10${CYAN}]${NC}  Add DNS Servers"
    echo -e "  ${CYAN}[${WHITE}11${CYAN}]${NC}  Remove DNS Server"
    echo -e "  ${CYAN}[${WHITE}12${CYAN}]${NC}  Scan & Add Clean DNS"
    echo -e "  ${CYAN}[${WHITE}13${CYAN}]${NC}  Update Script"
    echo -e "  ${CYAN}[${WHITE}14${CYAN}]${NC}  Uninstall"
    echo -e "  ${CYAN}[${WHITE}0${CYAN}]${NC}   Exit"
    echo ""
    echo -e "  ${GRAY}─────────────────────────────────────────────────────${NC}"
    echo -ne "  ${WHITE}Select: ${CYAN}"
}

save_config() {
    cat > "$CONFIG_FILE" << EOF
# DNSTT-DNS-Changer Configuration v1.8.0
# Updated: $(date)

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
EOF
}

full_stop() {
    systemctl stop "$SERVICE_NAME" 2>/dev/null
    pkill -9 -f "dnstt-client" 2>/dev/null
    sleep 2
}

full_start() {
    chmod +x /root/dnstt-client-linux-amd64 2>/dev/null
    systemctl start "$SERVICE_NAME" 2>/dev/null
    sleep 5
}

opt_status() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== Status ===${NC}"; echo ""
    echo -e "  ${WHITE}Files:${NC}"
    [ -f "/root/dnstt-client-linux-amd64" ] && echo -e "    ${GREEN}✓ dnstt-client${NC}" || echo -e "    ${RED}✗ dnstt-client${NC}"
    [ -f "/root/pub.key" ] && echo -e "    ${GREEN}✓ pub.key${NC}" || echo -e "    ${RED}✗ pub.key${NC}"
    echo ""
    if [ "$(get_status)" = "active" ]; then
        echo -e "  ${GREEN}● Service RUNNING${NC}"
        local pid=$(systemctl show -p MainPID "$SERVICE_NAME" | cut -d= -f2)
        [ "$pid" != "0" ] && echo -e "  ${WHITE}PID:${NC}    $pid"
        local up=$(ps -o etime= -p "$pid" 2>/dev/null | xargs)
        [ -n "$up" ] && echo -e "  ${WHITE}Uptime:${NC} $up"
        load_config
        echo -e "  ${WHITE}SOCKS5:${NC} ${LOCAL_LISTEN}"
        local dc=$(count_dnstt)
        echo -e "  ${WHITE}DNSTT:${NC}  $dc process(es)"
        local sw=$(journalctl -u "$SERVICE_NAME" --no-pager 2>/dev/null | grep -c "SWITCH" || echo 0)
        echo -e "  ${WHITE}Switches:${NC} $sw"
    else
        echo -e "  ${RED}● Service STOPPED${NC}"
    fi
    echo ""
    systemctl status "$SERVICE_NAME" --no-pager -l 2>/dev/null | head -20 | sed 's/^/  /'
    echo ""; read -p "  Press Enter..."
}

opt_start() {
    show_banner
    if [ ! -f "/root/dnstt-client-linux-amd64" ] || [ ! -f "/root/pub.key" ]; then
        echo -e "  ${RED}Missing files in /root/!${NC}"; echo ""; read -p "  Press Enter..."; return
    fi
    echo -e "  ${YELLOW}Starting...${NC}"
    full_start
    [ "$(get_status)" = "active" ] && echo -e "  ${GREEN}✓ Started${NC}" || echo -e "  ${RED}✗ Failed${NC}"
    echo ""; read -p "  Press Enter..."
}

opt_stop() {
    show_banner; echo -e "  ${YELLOW}Stopping...${NC}"
    full_stop
    echo -e "  ${GREEN}✓${NC}"; echo ""; read -p "  Press Enter..."
}

opt_restart() {
    show_banner; echo -e "  ${YELLOW}Restarting...${NC}"
    full_stop; full_start
    [ "$(get_status)" = "active" ] && echo -e "  ${GREEN}✓${NC}" || echo -e "  ${RED}✗${NC}"
    echo ""; read -p "  Press Enter..."
}

opt_logs() {
    show_banner
    echo -e "  ${WHITE}=== Live Logs ===${NC} ${GRAY}(Ctrl+C to stop)${NC}"; echo ""
    journalctl -u "$SERVICE_NAME" -f --no-pager 2>/dev/null | while IFS= read -r line; do
        if echo "$line" | grep -q "ERROR"; then echo -e "  ${RED}$line${NC}"
        elif echo "$line" | grep -q "SWITCH"; then echo -e "  ${PURPLE}$line${NC}"
        elif echo "$line" | grep -q "WARNING"; then echo -e "  ${YELLOW}$line${NC}"
        else echo -e "  ${GREEN}$line${NC}"; fi
    done
}

opt_history() {
    show_banner
    echo -e "  ${WHITE}=== History ===${NC}"; echo ""
    local logs=$(journalctl -u "$SERVICE_NAME" --no-pager 2>/dev/null | grep -E "SWITCH|ERROR|Connected" | tail -40)
    [ -z "$logs" ] && echo -e "  ${GRAY}Nothing yet.${NC}" || echo "$logs" | sed 's/^/  /'
    echo ""; read -p "  Press Enter..."
}

opt_edit() {
    local ed="nano"; command -v nano &>/dev/null || ed="vi"
    $ed "$CONFIG_FILE"
    echo -ne "  ${YELLOW}Restart? (y/n): ${NC}"; read -r a
    [ "$a" = "y" ] && { full_stop; full_start; echo -e "  ${GREEN}✓${NC}"; }
    read -p "  Press Enter..."
}

opt_test() {
    show_banner; echo -e "  ${WHITE}=== Test ===${NC}"; echo ""
    load_config
    echo -ne "  Service:  "; [ "$(get_status)" = "active" ] && echo -e "${GREEN}✓${NC}" || { echo -e "${RED}✗${NC}"; read -p "  Press Enter..."; return; }
    local port="${LOCAL_LISTEN##*:}"
    echo -ne "  Port $port: "; ss -tlnp 2>/dev/null | grep -q ":${port}" && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
    echo -ne "  SOCKS:    "
    if command -v curl &>/dev/null; then
        if timeout 15 curl -s --socks5 "$LOCAL_LISTEN" "http://httpbin.org/ip" -o /tmp/dt 2>/dev/null; then
            echo -e "${GREEN}✓ $(cat /tmp/dt 2>/dev/null)${NC}"
        else echo -e "${RED}✗${NC}"; fi; rm -f /tmp/dt
    else echo -e "${YELLOW}no curl${NC}"; fi
    echo ""; echo -e "  ${WHITE}Servers (${#DNS_SERVERS[@]}):${NC}"
    for i in "${!DNS_SERVERS[@]}"; do echo "    [$((i+1))] ${DNS_SERVERS[$i]} -> ${DOMAINS[$i]}"; done
    echo ""; read -p "  Press Enter..."
}

opt_showconf() {
    show_banner; echo -e "  ${WHITE}=== Config ===${NC}"; echo ""
    cat "$CONFIG_FILE" | sed 's/^/  /'
    echo ""; read -p "  Press Enter..."
}

opt_add_dns() {
    show_banner; echo -e "  ${WHITE}=== Add DNS ===${NC}"; echo ""
    load_config
    [ ${#DNS_SERVERS[@]} -gt 0 ] && { echo -e "  ${WHITE}Current (${#DNS_SERVERS[@]}):${NC}"; for i in "${!DNS_SERVERS[@]}"; do echo "    [$((i+1))] ${DNS_SERVERS[$i]} -> ${DOMAINS[$i]}"; done; echo ""; }
    echo -e "  ${CYAN}Enter servers. Empty = done:${NC}"; echo ""
    local added=0 num=$((${#DNS_SERVERS[@]}+1))
    while true; do
        echo -ne "  Server $num (ip:port): "; read -r nd
        [ -z "$nd" ] && break
        echo -ne "  Domain: "; read -r nm
        [ -z "$nm" ] && { echo -e "  ${RED}Need domain!${NC}"; continue; }
        DNS_SERVERS+=("$nd"); DOMAINS+=("$nm"); added=$((added+1)); num=$((num+1))
        echo -e "  ${GREEN}✓${NC}"; echo ""
    done
    if [ $added -gt 0 ]; then
        save_config; echo -e "  ${GREEN}✓ $added added. Total: ${#DNS_SERVERS[@]}${NC}"
        echo ""; echo -ne "  ${YELLOW}Restart? (y/n): ${NC}"; read -r r
        [ "$r" = "y" ] && { full_stop; full_start; echo -e "  ${GREEN}✓${NC}"; }
    fi
    read -p "  Press Enter..."
}

opt_remove_dns() {
    show_banner; echo -e "  ${WHITE}=== Remove DNS ===${NC}"; echo ""
    load_config
    [ ${#DNS_SERVERS[@]} -le 1 ] && { echo -e "  ${RED}Need at least 1!${NC}"; read -p "  Press Enter..."; return; }
    for i in "${!DNS_SERVERS[@]}"; do echo "    ${CYAN}[$((i+1))]${NC} ${DNS_SERVERS[$i]} -> ${DOMAINS[$i]}"; done
    echo ""; echo -ne "  Remove # (0=cancel): "; read -r rn
    [ -z "$rn" ] || [ "$rn" = "0" ] && { read -p "  Press Enter..."; return; }
    [[ ! "$rn" =~ ^[0-9]+$ ]] && { echo -e "  ${RED}Invalid${NC}"; read -p "  Press Enter..."; return; }
    local idx=$((rn-1))
    [ $idx -lt 0 ] || [ $idx -ge ${#DNS_SERVERS[@]} ] && { echo -e "  ${RED}Invalid${NC}"; read -p "  Press Enter..."; return; }
    echo -ne "  ${RED}Remove ${DNS_SERVERS[$idx]}? (y/n): ${NC}"; read -r cf
    [ "$cf" != "y" ] && { read -p "  Press Enter..."; return; }
    local td=() tm=()
    for i in "${!DNS_SERVERS[@]}"; do [ "$i" -ne "$idx" ] && { td+=("${DNS_SERVERS[$i]}"); tm+=("${DOMAINS[$i]}"); }; done
    DNS_SERVERS=("${td[@]}"); DOMAINS=("${tm[@]}")
    save_config; echo -e "  ${GREEN}✓ Removed. Remaining: ${#DNS_SERVERS[@]}${NC}"
    echo ""; echo -ne "  ${YELLOW}Restart? (y/n): ${NC}"; read -r r
    [ "$r" = "y" ] && { full_stop; full_start; echo -e "  ${GREEN}✓${NC}"; }
    read -p "  Press Enter..."
}

# ═══════════════════════════════════════════════════════════
# DNS SCANNER
# ═══════════════════════════════════════════════════════════
opt_scan_dns() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== DNS Scanner ===${NC}"
    echo ""
    echo -e "  ${CYAN}This will scan random IP ranges to find working${NC}"
    echo -e "  ${CYAN}open DNS resolvers and add them to your config.${NC}"
    echo ""

    # Check dig
    if ! command -v dig &>/dev/null; then
        echo -e "  ${YELLOW}Installing dnsutils...${NC}"
        apt-get install -y -qq dnsutils 2>/dev/null || yum install -y -q bind-utils 2>/dev/null
        if ! command -v dig &>/dev/null; then
            echo -e "  ${RED}Cannot install dig! Install manually: apt install dnsutils${NC}"
            read -p "  Press Enter..."; return
        fi
        echo -e "  ${GREEN}✓ Installed${NC}"
    fi

    # Settings
    echo -ne "  ${WHITE}How many clean DNS to find? [30]: ${NC}"
    read -r scan_target
    scan_target=${scan_target:-30}

    echo -ne "  ${WHITE}Domain for all found DNS: ${NC}"
    read -r scan_domain
    if [ -z "$scan_domain" ]; then
        echo -e "  ${RED}Domain required!${NC}"
        read -p "  Press Enter..."; return
    fi

    echo -ne "  ${WHITE}DNS port [53]: ${NC}"
    read -r scan_port
    scan_port=${scan_port:-53}

    echo -ne "  ${WHITE}Replace current DNS list or add to it? (replace/add) [add]: ${NC}"
    read -r scan_mode
    scan_mode=${scan_mode:-add}

    echo ""
    echo -e "  ${YELLOW}Scanning... Target: $scan_target clean DNS${NC}"
    echo -e "  ${GRAY}This may take a few minutes...${NC}"
    echo ""

    load_config

    if [ "$scan_mode" = "replace" ]; then
        DNS_SERVERS=()
        DOMAINS=()
    fi

    local found=0
    local tested=0
    local start_time=$(date +%s)

    # IP ranges known to have open resolvers
    local RANGES=(
        "1.0" "1.1" "4.2" "5.2" "8.8" "8.26"
        "9.9" "23.253" "37.235" "45.33" "45.90"
        "46.182" "51.15" "62.210" "64.6" "66.70"
        "74.82" "77.88" "78.46" "80.67" "80.80"
        "84.200" "85.214" "89.233" "91.239"
        "94.140" "101.226" "103.86" "104.236"
        "107.150" "108.61" "114.114" "115.159"
        "116.202" "116.203" "119.29" "123.125"
        "134.195" "136.144" "139.59" "139.162"
        "149.112" "156.154" "159.69" "159.89"
        "168.95" "172.64" "172.104" "176.9"
        "176.103" "178.79" "185.121" "185.184"
        "185.222" "185.228" "185.253" "188.166"
        "193.17" "193.110" "194.36" "195.10"
        "195.46" "198.101" "199.85" "203.67"
        "203.198" "207.148" "208.67" "208.76"
        "209.244" "216.146" "217.160"
    )

    while [ $found -lt $scan_target ]; do
        # Pick random range
        local range_idx=$((RANDOM % ${#RANGES[@]}))
        local range="${RANGES[$range_idx]}"

        # Generate random last two octets
        local oct3=$((RANDOM % 256))
        local oct4=$((RANDOM % 254 + 1))
        local ip="${range}.${oct3}.${oct4}"

        tested=$((tested + 1))

        # Quick test: can this IP respond to DNS query?
        local result=$(timeout 2 dig @"$ip" google.com +short +time=1 +tries=1 2>/dev/null)

        if [ -n "$result" ] && echo "$result" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; then
            # Verify: test again with different domain
            local result2=$(timeout 2 dig @"$ip" cloudflare.com +short +time=1 +tries=1 2>/dev/null)

            if [ -n "$result2" ] && echo "$result2" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; then
                # Check if already in list
                local already=false
                for existing in "${DNS_SERVERS[@]}"; do
                    [ "$existing" = "${ip}:${scan_port}" ] && { already=true; break; }
                done

                if [ "$already" = false ]; then
                    found=$((found + 1))
                    DNS_SERVERS+=("${ip}:${scan_port}")
                    DOMAINS+=("$scan_domain")
                    echo -e "  ${GREEN}[${found}/${scan_target}]${NC} Found: ${CYAN}${ip}:${scan_port}${NC} ${GRAY}(tested: $tested)${NC}"
                fi
            fi
        fi

        # Progress every 50 tests
        if [ $((tested % 50)) -eq 0 ] && [ $found -lt $scan_target ]; then
            local elapsed=$(( $(date +%s) - start_time ))
            echo -e "  ${GRAY}... tested $tested IPs, found $found DNS, ${elapsed}s elapsed${NC}"
        fi

        # Safety: don't scan forever
        if [ $tested -ge 5000 ] && [ $found -lt $scan_target ]; then
            echo -e "  ${YELLOW}Reached 5000 tests. Found $found out of $scan_target${NC}"
            break
        fi
    done

    local total_time=$(( $(date +%s) - start_time ))

    echo ""
    echo -e "  ${WHITE}═══════════════════════════════════${NC}"
    echo -e "  ${WHITE}Scan Complete!${NC}"
    echo -e "  ${WHITE}Found:${NC}   ${GREEN}$found${NC} clean DNS"
    echo -e "  ${WHITE}Tested:${NC}  $tested IPs"
    echo -e "  ${WHITE}Time:${NC}    ${total_time}s"
    echo -e "  ${WHITE}Total:${NC}   ${#DNS_SERVERS[@]} DNS in config"
    echo -e "  ${WHITE}═══════════════════════════════════${NC}"

    if [ $found -gt 0 ]; then
        echo ""
        echo -ne "  ${WHITE}Save to config? (y/n): ${NC}"
        read -r save_yn
        if [ "$save_yn" = "y" ]; then
            save_config
            echo -e "  ${GREEN}✓ Saved!${NC}"
            echo ""
            echo -ne "  ${YELLOW}Restart service? (y/n): ${NC}"
            read -r restart_yn
            if [ "$restart_yn" = "y" ]; then
                full_stop; full_start
                echo -e "  ${GREEN}✓ Restarted${NC}"
            fi
        fi
    else
        echo -e "  ${RED}No DNS found. Try again or add manually.${NC}"
    fi

    read -p "  Press Enter..."
}

opt_update() {
    show_banner; echo -e "  ${WHITE}=== Update ===${NC}"
    echo -e "  Current: ${CYAN}$VERSION${NC} | Config: ${GREEN}safe${NC}"
    echo -ne "  Update? (y/n): "; read -r u
    [ "$u" != "y" ] && { read -p "  Press Enter..."; return; }
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
    systemctl daemon-reload
    full_start
    systemctl is-active --quiet "$SERVICE_NAME" && echo -e "  ${GREEN}✓ Running!${NC}" || echo -e "  ${YELLOW}⚠${NC}"
    echo -e "  ${YELLOW}Run winnet-dnstt again${NC}"; echo ""; read -p "  Press Enter..."; exit 0
}

opt_uninstall() {
    show_banner; echo -e "  ${RED}=== Uninstall ===${NC}"
    echo -ne "  Type 'yes': "; read -r c
    [ "$c" != "yes" ] && { read -p "  Press Enter..."; return; }
    full_stop; systemctl disable "$SERVICE_NAME" 2>/dev/null
    rm -f /etc/systemd/system/${SERVICE_NAME}.service /usr/local/bin/dnstt-failover /usr/local/bin/winnet-dnstt
    echo -ne "  Remove config? (y/n): "; read -r rc
    [ "$rc" = "y" ] && rm -rf /etc/dnstt-DNS-changer
    systemctl daemon-reload 2>/dev/null
    echo -e "  ${GREEN}✓${NC}"; exit 0
}

# ═══ MAIN ═══
check_root
while true; do
    show_banner; show_status_bar; show_menu; read -r choice; echo -e "${NC}"
    case $choice in
        1) opt_status ;; 2) opt_start ;; 3) opt_stop ;; 4) opt_restart ;;
        5) opt_logs ;; 6) opt_history ;; 7) opt_edit ;; 8) opt_test ;;
        9) opt_showconf ;; 10) opt_add_dns ;; 11) opt_remove_dns ;;
        12) opt_scan_dns ;; 13) opt_update ;; 14) opt_uninstall ;;
        0) echo -e "  ${GREEN}Bye!${NC}"; exit 0 ;;
        *) echo -e "  ${RED}Invalid!${NC}"; sleep 1 ;;
    esac
done
