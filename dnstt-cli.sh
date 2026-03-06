#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer CLI (winnet-dnstt) v1.5.0
# https://github.com/Win-Net/dnstt-DNS-changer
# ═══════════════════════════════════════════════════════════

VERSION="1.5.0"
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

show_status_bar() {
    local s=$(get_status)
    [ "$s" = "active" ] && echo -e "  ${WHITE}Service: ${GREEN}● RUNNING${NC}" || echo -e "  ${WHITE}Service: ${RED}● STOPPED${NC}"
    [ ! -f "/root/dnstt-client-linux-amd64" ] && echo -e "  ${RED}⚠ Missing: /root/dnstt-client-linux-amd64${NC}"
    [ ! -f "/root/pub.key" ] && echo -e "  ${RED}⚠ Missing: /root/pub.key${NC}"
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
    echo -e "  ${CYAN}[${WHITE}7${CYAN}]${NC}   Edit Config (manual)"
    echo -e "  ${CYAN}[${WHITE}8${CYAN}]${NC}   Test Connection"
    echo -e "  ${CYAN}[${WHITE}9${CYAN}]${NC}   Show Config"
    echo -e "  ${CYAN}[${WHITE}10${CYAN}]${NC}  Add DNS Servers"
    echo -e "  ${CYAN}[${WHITE}11${CYAN}]${NC}  Remove DNS Server"
    echo -e "  ${CYAN}[${WHITE}12${CYAN}]${NC}  Auto-Restart Settings"
    echo -e "  ${CYAN}[${WHITE}13${CYAN}]${NC}  Update Script"
    echo -e "  ${CYAN}[${WHITE}14${CYAN}]${NC}  Uninstall"
    echo -e "  ${CYAN}[${WHITE}0${CYAN}]${NC}   Exit"
    echo ""
    echo -e "  ${GRAY}─────────────────────────────────────────────────────${NC}"
    echo -ne "  ${WHITE}Select: ${CYAN}"
}

save_config() {
    cat > "$CONFIG_FILE" << EOF
# DNSTT-DNS-Changer Configuration
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
HEALTH_CHECK_INTERVAL=${HEALTH_CHECK_INTERVAL:-30}
MAX_FAILURES=${MAX_FAILURES:-3}
ALL_FAILED_WAIT=${ALL_FAILED_WAIT:-30}
AUTO_RESTART_ENABLED=${AUTO_RESTART_ENABLED:-true}
AUTO_RESTART_CHECK=${AUTO_RESTART_CHECK:-10}
AUTO_RESTART_MAX_TRIES=${AUTO_RESTART_MAX_TRIES:-3}
SOCKS_TEST_ENABLED=${SOCKS_TEST_ENABLED:-false}
SOCKS_TEST_URL="${SOCKS_TEST_URL:-http://www.google.com}"
SOCKS_TEST_TIMEOUT=${SOCKS_TEST_TIMEOUT:-15}
EOF
}

opt_status() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== Service Status ===${NC}"
    echo ""
    echo -e "  ${WHITE}Files:${NC}"
    [ -f "/root/dnstt-client-linux-amd64" ] && echo -e "    ${GREEN}✓ dnstt-client${NC}" || echo -e "    ${RED}✗ dnstt-client MISSING${NC}"
    [ -f "/root/pub.key" ] && echo -e "    ${GREEN}✓ pub.key${NC}" || echo -e "    ${RED}✗ pub.key MISSING${NC}"
    echo ""
    local s=$(get_status)
    if [ "$s" = "active" ]; then
        echo -e "  ${GREEN}● RUNNING${NC}"
        local pid=$(systemctl show -p MainPID "$SERVICE_NAME" | cut -d= -f2)
        [ "$pid" != "0" ] && echo -e "  ${WHITE}PID:${NC}      $pid"
        local up=$(ps -o etime= -p "$pid" 2>/dev/null | xargs)
        [ -n "$up" ] && echo -e "  ${WHITE}Uptime:${NC}   $up"
        load_config
        local port="${LOCAL_LISTEN##*:}"
        echo -e "  ${WHITE}SOCKS5:${NC}   127.0.0.1:$port"
        ss -tlnp 2>/dev/null | grep -q ":${port}" && echo -e "  ${WHITE}Port:${NC}     ${GREEN}● listening${NC}" || echo -e "  ${WHITE}Port:${NC}     ${RED}● not listening${NC}"

        # Count dnstt-client processes
        local dnstt_count=$(pgrep -c -f "dnstt-client" 2>/dev/null || echo 0)
        echo -e "  ${WHITE}DNSTT:${NC}    $dnstt_count process(es)"

        local sw=$(journalctl -u "$SERVICE_NAME" --no-pager 2>/dev/null | grep -c "SWITCH" 2>/dev/null || echo 0)
        local rs=$(journalctl -u "$SERVICE_NAME" --no-pager 2>/dev/null | grep -c "RESTART" 2>/dev/null || echo 0)
        echo -e "  ${WHITE}Switches:${NC} $sw"
        echo -e "  ${WHITE}Restarts:${NC} $rs"
    else
        echo -e "  ${RED}● STOPPED${NC}"
    fi
    echo ""
    systemctl status "$SERVICE_NAME" --no-pager -l 2>/dev/null | head -15 | sed 's/^/  /'
    echo ""; read -p "  Press Enter..."
}

opt_start() {
    show_banner
    if [ ! -f "/root/dnstt-client-linux-amd64" ] || [ ! -f "/root/pub.key" ]; then
        echo -e "  ${RED}Cannot start! Missing:${NC}"
        [ ! -f "/root/dnstt-client-linux-amd64" ] && echo -e "    ${RED}✗ /root/dnstt-client-linux-amd64${NC}"
        [ ! -f "/root/pub.key" ] && echo -e "    ${RED}✗ /root/pub.key${NC}"
        echo ""; read -p "  Press Enter..."; return
    fi
    chmod +x /root/dnstt-client-linux-amd64
    echo -e "  ${YELLOW}Starting...${NC}"
    systemctl start "$SERVICE_NAME" 2>/dev/null; sleep 3
    [ "$(get_status)" = "active" ] && echo -e "  ${GREEN}✓ Started${NC}" || echo -e "  ${RED}✗ Failed${NC}"
    echo ""; read -p "  Press Enter..."
}

opt_stop() {
    show_banner; echo -e "  ${YELLOW}Stopping...${NC}"
    systemctl stop "$SERVICE_NAME" 2>/dev/null
    pkill -9 -f "dnstt-client" 2>/dev/null; sleep 1
    echo -e "  ${GREEN}✓ Stopped${NC}"
    echo ""; read -p "  Press Enter..."
}

opt_restart() {
    show_banner; echo -e "  ${YELLOW}Restarting...${NC}"
    systemctl stop "$SERVICE_NAME" 2>/dev/null
    pkill -9 -f "dnstt-client" 2>/dev/null; sleep 2
    systemctl start "$SERVICE_NAME" 2>/dev/null; sleep 3
    [ "$(get_status)" = "active" ] && echo -e "  ${GREEN}✓ Restarted${NC}" || echo -e "  ${RED}✗ Failed${NC}"
    echo ""; read -p "  Press Enter..."
}

opt_logs() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== Live Logs ===${NC} ${GRAY}(Ctrl+C to stop)${NC}"
    echo ""
    journalctl -u "$SERVICE_NAME" -f --no-pager 2>/dev/null | while IFS= read -r line; do
        if echo "$line" | grep -q "ERROR"; then echo -e "  ${RED}$line${NC}"
        elif echo "$line" | grep -q "WARNING"; then echo -e "  ${YELLOW}$line${NC}"
        elif echo "$line" | grep -q "SWITCH"; then echo -e "  ${PURPLE}$line${NC}"
        elif echo "$line" | grep -q "RESTART"; then echo -e "  ${CYAN}$line${NC}"
        else echo -e "  ${GREEN}$line${NC}"; fi
    done
}

opt_switches() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== History ===${NC}"
    echo ""
    local logs=$(journalctl -u "$SERVICE_NAME" --no-pager 2>/dev/null | grep -E "SWITCH|RESTART")
    if [ -z "$logs" ]; then
        echo -e "  ${GRAY}No events yet.${NC}"
    else
        echo "$logs" | tail -30 | while IFS= read -r l; do
            if echo "$l" | grep -q "SWITCH"; then echo -e "  ${PURPLE}🔀 $l${NC}"
            else echo -e "  ${CYAN}🔄 $l${NC}"; fi
        done
    fi
    echo ""; read -p "  Press Enter..."
}

opt_edit() {
    local ed="nano"; command -v nano &>/dev/null || ed="vi"
    $ed "$CONFIG_FILE"
    echo -ne "  ${YELLOW}Restart? (y/n): ${NC}"; read -r a
    [ "$a" = "y" ] && { systemctl restart "$SERVICE_NAME" 2>/dev/null; sleep 2; echo -e "  ${GREEN}✓${NC}"; }
    read -p "  Press Enter..."
}

opt_test() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== Connection Test ===${NC}"
    echo ""
    load_config
    echo -ne "  ${WHITE}[1/3] Service...${NC}     "
    [ "$(get_status)" = "active" ] && echo -e "${GREEN}✓ Running${NC}" || { echo -e "${RED}✗ Stopped${NC}"; echo ""; read -p "  Press Enter..."; return; }
    local port="${LOCAL_LISTEN##*:}"
    echo -ne "  ${WHITE}[2/3] Port $port...${NC}  "
    ss -tlnp 2>/dev/null | grep -q ":${port}" && echo -e "${GREEN}✓ Listening${NC}" || echo -e "${RED}✗ Not listening${NC}"
    echo -ne "  ${WHITE}[3/3] SOCKS...${NC}      "
    if command -v curl &>/dev/null; then
        if timeout 15 curl -s --socks5 "$LOCAL_LISTEN" "http://httpbin.org/ip" > /tmp/dt_test 2>/dev/null; then
            local ip=$(grep -o '"origin": "[^"]*"' /tmp/dt_test | cut -d'"' -f4)
            echo -e "${GREEN}✓ OK (IP: $ip)${NC}"
        else echo -e "${RED}✗ Failed${NC}"; fi
        rm -f /tmp/dt_test
    else echo -e "${YELLOW}⚠ curl not found${NC}"; fi
    echo ""
    echo -e "  ${WHITE}Servers:${NC}"
    for i in "${!DNS_SERVERS[@]}"; do echo -e "    ${CYAN}[$((i+1))]${NC} ${DNS_SERVERS[$i]} -> ${DOMAINS[$i]}"; done
    echo ""; read -p "  Press Enter..."
}

opt_showconf() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== Config ===${NC}"
    echo ""
    while IFS= read -r line; do
        [[ "$line" =~ ^# ]] && echo -e "  ${GRAY}$line${NC}" || echo -e "  ${CYAN}$line${NC}"
    done < "$CONFIG_FILE"
    echo ""; read -p "  Press Enter..."
}

opt_add_dns() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== Add DNS Servers ===${NC}"
    echo ""
    load_config
    if [ ${#DNS_SERVERS[@]} -gt 0 ]; then
        echo -e "  ${WHITE}Current:${NC}"
        for i in "${!DNS_SERVERS[@]}"; do echo -e "    ${CYAN}[$((i+1))]${NC} ${DNS_SERVERS[$i]} -> ${DOMAINS[$i]}"; done
        echo ""
    fi
    echo -e "  ${CYAN}Enter servers. Empty input = done:${NC}"
    echo ""
    local added=0; local num=$((${#DNS_SERVERS[@]} + 1))
    while true; do
        echo -ne "  ${WHITE}Server $num (ip:port or Enter=done): ${NC}"; read -r nd
        [ -z "$nd" ] && break
        echo -ne "  ${WHITE}Domain: ${NC}"; read -r nm
        [ -z "$nm" ] && { echo -e "  ${RED}Need domain!${NC}"; continue; }
        DNS_SERVERS+=("$nd"); DOMAINS+=("$nm")
        added=$((added + 1)); num=$((num + 1))
        echo -e "  ${GREEN}✓ Added${NC}"; echo ""
    done
    if [ $added -gt 0 ]; then
        save_config
        echo -e "  ${GREEN}✓ $added server(s) added${NC}"
        echo ""
        echo -e "  ${WHITE}All servers:${NC}"
        for i in "${!DNS_SERVERS[@]}"; do echo -e "    ${CYAN}[$((i+1))]${NC} ${DNS_SERVERS[$i]} -> ${DOMAINS[$i]}"; done
        echo ""
        echo -ne "  ${YELLOW}Restart? (y/n): ${NC}"; read -r r
        [ "$r" = "y" ] && { systemctl restart "$SERVICE_NAME" 2>/dev/null; sleep 2; echo -e "  ${GREEN}✓${NC}"; }
    fi
    read -p "  Press Enter..."
}

opt_remove_dns() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== Remove DNS Server ===${NC}"
    echo ""
    load_config
    if [ ${#DNS_SERVERS[@]} -le 1 ]; then
        echo -e "  ${RED}Need at least 1 server!${NC}"; echo ""; read -p "  Press Enter..."; return
    fi
    echo -e "  ${WHITE}Servers:${NC}"
    for i in "${!DNS_SERVERS[@]}"; do echo -e "    ${CYAN}[$((i+1))]${NC} ${DNS_SERVERS[$i]} -> ${DOMAINS[$i]}"; done
    echo ""
    echo -ne "  ${WHITE}Remove # (0=cancel): ${NC}"; read -r rn
    [ -z "$rn" ] || [ "$rn" = "0" ] && { read -p "  Press Enter..."; return; }
    [[ ! "$rn" =~ ^[0-9]+$ ]] && { echo -e "  ${RED}Invalid!${NC}"; read -p "  Press Enter..."; return; }
    local idx=$((rn - 1))
    [ $idx -lt 0 ] || [ $idx -ge ${#DNS_SERVERS[@]} ] && { echo -e "  ${RED}Invalid!${NC}"; read -p "  Press Enter..."; return; }
    echo -e "  ${YELLOW}Remove ${DNS_SERVERS[$idx]}?${NC}"
    echo -ne "  ${RED}Confirm (y/n): ${NC}"; read -r cf
    [ "$cf" != "y" ] && { read -p "  Press Enter..."; return; }
    local td=(); local tm=()
    for i in "${!DNS_SERVERS[@]}"; do
        [ "$i" -ne "$idx" ] && { td+=("${DNS_SERVERS[$i]}"); tm+=("${DOMAINS[$i]}"); }
    done
    DNS_SERVERS=("${td[@]}"); DOMAINS=("${tm[@]}")
    save_config
    echo -e "  ${GREEN}✓ Removed${NC}"
    echo ""
    echo -e "  ${WHITE}Remaining:${NC}"
    for i in "${!DNS_SERVERS[@]}"; do echo -e "    ${CYAN}[$((i+1))]${NC} ${DNS_SERVERS[$i]} -> ${DOMAINS[$i]}"; done
    echo ""
    echo -ne "  ${YELLOW}Restart? (y/n): ${NC}"; read -r r
    [ "$r" = "y" ] && { systemctl restart "$SERVICE_NAME" 2>/dev/null; sleep 2; echo -e "  ${GREEN}✓${NC}"; }
    read -p "  Press Enter..."
}

opt_autorestart() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== Auto-Restart Settings ===${NC}"
    echo ""
    load_config
    local ac=${AUTO_RESTART_CHECK:-10}
    local am=${AUTO_RESTART_MAX_TRIES:-3}
    echo -e "  ${WHITE}Check interval:${NC} ${CYAN}${ac}s${NC}"
    echo -e "  ${WHITE}Max tries before switch:${NC} ${CYAN}${am}${NC}"
    echo ""
    echo -e "    ${CYAN}[1]${NC} Change check interval"
    echo -e "    ${CYAN}[2]${NC} Change max tries"
    echo -e "    ${CYAN}[0]${NC} Back"
    echo ""
    echo -ne "  ${WHITE}Select: ${NC}"; read -r ch
    case $ch in
        1)
            echo -ne "  ${WHITE}Seconds [$ac]: ${NC}"; read -r ni
            [ -n "$ni" ] && { AUTO_RESTART_CHECK=$ni; save_config; echo -e "  ${GREEN}✓ Set to ${ni}s${NC}"; }
            ;;
        2)
            echo -ne "  ${WHITE}Max tries [$am]: ${NC}"; read -r nm
            [ -n "$nm" ] && { AUTO_RESTART_MAX_TRIES=$nm; save_config; echo -e "  ${GREEN}✓ Set to $nm${NC}"; }
            ;;
        0) return ;;
    esac
    echo -ne "  ${YELLOW}Restart? (y/n): ${NC}"; read -r r
    [ "$r" = "y" ] && { systemctl restart "$SERVICE_NAME" 2>/dev/null; sleep 2; echo -e "  ${GREEN}✓${NC}"; }
    read -p "  Press Enter..."
}

opt_update() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== Update ===${NC}"
    echo -e "  ${WHITE}Current: ${CYAN}$VERSION${NC} | Config: ${GREEN}safe${NC}"
    echo -ne "  ${WHITE}Update? (y/n): ${NC}"; read -r u
    [ "$u" != "y" ] && { read -p "  Press Enter..."; return; }
    echo ""
    systemctl stop "$SERVICE_NAME" 2>/dev/null; pkill -9 -f "dnstt-client" 2>/dev/null
    echo -ne "  Failover... "; curl -sL "$REPO/dnstt-failover.sh" -o /usr/local/bin/dnstt-failover && chmod +x /usr/local/bin/dnstt-failover && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
    echo -ne "  CLI...      "; curl -sL "$REPO/dnstt-cli.sh" -o /usr/local/bin/winnet-dnstt && chmod +x /usr/local/bin/winnet-dnstt && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
    echo -ne "  Service...  "
    cat > /etc/systemd/system/${SERVICE_NAME}.service << 'SVCEOF'
[Unit]
Description=DNSTT-DNS-Changer Tunnel Service
After=network.target network-online.target
Wants=network-online.target
[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/local/bin/dnstt-failover
Restart=on-failure
RestartSec=10s
StandardOutput=journal
StandardError=journal
TimeoutStopSec=15
KillMode=control-group
[Install]
WantedBy=multi-user.target
SVCEOF
    systemctl daemon-reload; echo -e "${GREEN}✓${NC}"
    systemctl start "$SERVICE_NAME" 2>/dev/null; sleep 3
    systemctl is-active --quiet "$SERVICE_NAME" && echo -e "  ${GREEN}✓ Running!${NC}" || echo -e "  ${YELLOW}⚠${NC}"
    echo -e "  ${YELLOW}Run ${WHITE}winnet-dnstt${YELLOW} again${NC}"
    echo ""; read -p "  Press Enter..."; exit 0
}

opt_uninstall() {
    show_banner
    echo -e "  ${RED}${BOLD}=== Uninstall ===${NC}"
    echo -ne "  ${RED}Type 'yes': ${NC}"; read -r c
    [ "$c" != "yes" ] && { echo -e "  ${GREEN}Cancelled${NC}"; read -p "  Press Enter..."; return; }
    systemctl stop "$SERVICE_NAME" 2>/dev/null; systemctl disable "$SERVICE_NAME" 2>/dev/null
    pkill -9 -f "dnstt-client" 2>/dev/null
    rm -f /etc/systemd/system/${SERVICE_NAME}.service /usr/local/bin/dnstt-failover /usr/local/bin/winnet-dnstt
    echo -ne "  ${YELLOW}Remove config? (y/n): ${NC}"; read -r rc
    [ "$rc" = "y" ] && rm -rf /etc/dnstt-DNS-changer
    systemctl daemon-reload 2>/dev/null
    echo -e "  ${GREEN}✓ Done${NC}"; exit 0
}

check_root
while true; do
    show_banner; show_status_bar; show_menu; read -r choice; echo -e "${NC}"
    case $choice in
        1) opt_status ;; 2) opt_start ;; 3) opt_stop ;; 4) opt_restart ;;
        5) opt_logs ;; 6) opt_switches ;; 7) opt_edit ;; 8) opt_test ;;
        9) opt_showconf ;; 10) opt_add_dns ;; 11) opt_remove_dns ;;
        12) opt_autorestart ;; 13) opt_update ;; 14) opt_uninstall ;;
        0) echo -e "  ${GREEN}Bye!${NC}"; exit 0 ;;
        *) echo -e "  ${RED}Invalid!${NC}"; sleep 1 ;;
    esac
done
