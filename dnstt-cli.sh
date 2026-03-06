#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer CLI (winnet-dnstt) v1.1.0
# https://github.com/Win-Net/dnstt-DNS-changer
# ═══════════════════════════════════════════════════════════

VERSION="1.1.0"
SERVICE_NAME="dnstt-DNS-changer"
CONFIG_FILE="/etc/dnstt-DNS-changer/config.conf"

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

show_status_bar() {
    local s=$(get_status)
    [ "$s" = "active" ] && echo -e "  ${WHITE}Service: ${GREEN}● RUNNING${NC}" || echo -e "  ${WHITE}Service: ${RED}● STOPPED${NC}"
    
    # Check required files
    if [ ! -f "/root/dnstt-client-linux-amd64" ]; then
        echo -e "  ${RED}⚠ Missing: /root/dnstt-client-linux-amd64${NC}"
    fi
    if [ ! -f "/root/pub.key" ]; then
        echo -e "  ${RED}⚠ Missing: /root/pub.key${NC}"
    fi
    
    echo -e "  ${GRAY}─────────────────────────────────────────────────────${NC}"
    echo ""
}

show_menu() {
    echo -e "  ${WHITE}${BOLD}Menu:${NC}"
    echo ""
    echo -e "  ${CYAN}[${WHITE}1${CYAN}]${NC}   Service Status & Details"
    echo -e "  ${CYAN}[${WHITE}2${CYAN}]${NC}   Start Service"
    echo -e "  ${CYAN}[${WHITE}3${CYAN}]${NC}   Stop Service"
    echo -e "  ${CYAN}[${WHITE}4${CYAN}]${NC}   Restart Service"
    echo -e "  ${CYAN}[${WHITE}5${CYAN}]${NC}   View Live Logs"
    echo -e "  ${CYAN}[${WHITE}6${CYAN}]${NC}   Server Switch History"
    echo -e "  ${CYAN}[${WHITE}7${CYAN}]${NC}   Edit Configuration"
    echo -e "  ${CYAN}[${WHITE}8${CYAN}]${NC}   Test Connection"
    echo -e "  ${CYAN}[${WHITE}9${CYAN}]${NC}   Show Current Config"
    echo -e "  ${CYAN}[${WHITE}10${CYAN}]${NC}  Uninstall"
    echo -e "  ${CYAN}[${WHITE}0${CYAN}]${NC}   Exit"
    echo ""
    echo -e "  ${GRAY}─────────────────────────────────────────────────────${NC}"
    echo -ne "  ${WHITE}Select: ${CYAN}"
}

opt_status() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== Service Status ===${NC}"
    echo ""

    # File checks
    echo -e "  ${WHITE}Required Files:${NC}"
    [ -f "/root/dnstt-client-linux-amd64" ] && echo -e "    ${GREEN}✓ /root/dnstt-client-linux-amd64${NC}" || echo -e "    ${RED}✗ /root/dnstt-client-linux-amd64 MISSING${NC}"
    [ -f "/root/pub.key" ] && echo -e "    ${GREEN}✓ /root/pub.key${NC}" || echo -e "    ${RED}✗ /root/pub.key MISSING${NC}"
    echo ""

    local s=$(get_status)
    if [ "$s" = "active" ]; then
        echo -e "  ${GREEN}● RUNNING${NC}"
        local pid=$(systemctl show -p MainPID "$SERVICE_NAME" | cut -d= -f2)
        [ "$pid" != "0" ] && echo -e "  ${WHITE}PID:${NC}      $pid"
        local up=$(ps -o etime= -p "$pid" 2>/dev/null | xargs)
        [ -n "$up" ] && echo -e "  ${WHITE}Uptime:${NC}   $up"
        source "$CONFIG_FILE" 2>/dev/null
        local port="${LOCAL_LISTEN##*:}"
        echo -e "  ${WHITE}SOCKS5:${NC}   127.0.0.1:$port"
        ss -tlnp 2>/dev/null | grep -q ":${port}" && echo -e "  ${WHITE}Port:${NC}     ${GREEN}● $port listening${NC}" || echo -e "  ${WHITE}Port:${NC}     ${RED}● $port not listening${NC}"
        local sw=$(journalctl -u "$SERVICE_NAME" --no-pager 2>/dev/null | grep -c "SWITCH")
        echo -e "  ${WHITE}Switches:${NC} $sw"
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
        echo -e "  ${RED}Cannot start! Missing files:${NC}"
        [ ! -f "/root/dnstt-client-linux-amd64" ] && echo -e "    ${RED}✗ /root/dnstt-client-linux-amd64${NC}"
        [ ! -f "/root/pub.key" ] && echo -e "    ${RED}✗ /root/pub.key${NC}"
        echo ""
        echo -e "  ${YELLOW}Upload these files to /root/ first${NC}"
        echo ""; read -p "  Press Enter..."; return
    fi
    echo -e "  ${YELLOW}Starting...${NC}"
    systemctl start "$SERVICE_NAME" 2>/dev/null; sleep 3
    [ "$(get_status)" = "active" ] && echo -e "  ${GREEN}✓ Started${NC}" || echo -e "  ${RED}✗ Failed. Check logs (option 5)${NC}"
    echo ""; read -p "  Press Enter..."
}

opt_stop() {
    show_banner; echo -e "  ${YELLOW}Stopping...${NC}"
    systemctl stop "$SERVICE_NAME" 2>/dev/null; sleep 1
    echo -e "  ${GREEN}✓ Stopped${NC}"
    echo ""; read -p "  Press Enter..."
}

opt_restart() {
    show_banner; echo -e "  ${YELLOW}Restarting...${NC}"
    systemctl restart "$SERVICE_NAME" 2>/dev/null; sleep 3
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
        else echo -e "  ${GREEN}$line${NC}"; fi
    done
}

opt_switches() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== Switch History ===${NC}"
    echo ""
    local sw=$(journalctl -u "$SERVICE_NAME" --no-pager 2>/dev/null | grep "SWITCH")
    if [ -z "$sw" ]; then
        echo -e "  ${GRAY}No switches yet.${NC}"
    else
        echo "$sw" | tail -30 | while IFS= read -r l; do echo -e "  ${PURPLE}$l${NC}"; done
        echo ""; echo -e "  ${WHITE}Total: ${CYAN}$(echo "$sw" | wc -l)${NC}"
    fi
    echo ""; read -p "  Press Enter..."
}

opt_edit() {
    local ed="nano"; command -v nano &>/dev/null || ed="vi"
    $ed "$CONFIG_FILE"
    echo -ne "  ${YELLOW}Restart service? (y/n): ${NC}"; read -r a
    [ "$a" = "y" ] && { systemctl restart "$SERVICE_NAME" 2>/dev/null; sleep 2; echo -e "  ${GREEN}✓ Restarted${NC}"; }
    read -p "  Press Enter..."
}

opt_test() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== Connection Test ===${NC}"
    echo ""

    # File check
    echo -e "  ${WHITE}Files:${NC}"
    [ -f "/root/dnstt-client-linux-amd64" ] && echo -e "    ${GREEN}✓ dnstt-client binary${NC}" || echo -e "    ${RED}✗ dnstt-client binary MISSING${NC}"
    [ -f "/root/pub.key" ] && echo -e "    ${GREEN}✓ pub.key${NC}" || echo -e "    ${RED}✗ pub.key MISSING${NC}"
    echo ""

    source "$CONFIG_FILE" 2>/dev/null

    echo -ne "  ${WHITE}[1/3] Service...${NC}         "
    [ "$(get_status)" = "active" ] && echo -e "${GREEN}✓ Running${NC}" || { echo -e "${RED}✗ Stopped${NC}"; echo ""; read -p "  Press Enter..."; return; }

    local port="${LOCAL_LISTEN##*:}"
    echo -ne "  ${WHITE}[2/3] Port $port...${NC}      "
    ss -tlnp 2>/dev/null | grep -q ":${port}" && echo -e "${GREEN}✓ Listening${NC}" || echo -e "${RED}✗ Not listening${NC}"

    echo -ne "  ${WHITE}[3/3] SOCKS proxy...${NC}     "
    if command -v curl &>/dev/null; then
        if timeout 15 curl -s --socks5 "$LOCAL_LISTEN" "http://httpbin.org/ip" > /tmp/dt_test 2>/dev/null; then
            local ip=$(grep -o '"origin": "[^"]*"' /tmp/dt_test | cut -d'"' -f4)
            echo -e "${GREEN}✓ OK (IP: $ip)${NC}"
        else echo -e "${RED}✗ Failed${NC}"; fi
        rm -f /tmp/dt_test
    else echo -e "${YELLOW}⚠ curl not found${NC}"; fi

    echo ""
    echo -e "  ${WHITE}Configured Servers:${NC}"
    for i in "${!DNS_SERVERS[@]}"; do echo -e "    ${CYAN}[$((i+1))]${NC} ${DNS_SERVERS[$i]} -> ${DOMAINS[$i]}"; done
    echo ""
    echo -e "  ${WHITE}SOCKS5 Address:${NC} ${CYAN}127.0.0.1:${port}${NC}"
    echo ""; read -p "  Press Enter..."
}

opt_showconf() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== Current Config ===${NC}"
    echo ""
    while IFS= read -r line; do
        [[ "$line" =~ ^# ]] && echo -e "  ${GRAY}$line${NC}" || echo -e "  ${CYAN}$line${NC}"
    done < "$CONFIG_FILE"
    echo ""; read -p "  Press Enter..."
}

opt_uninstall() {
    show_banner
    echo -e "  ${RED}${BOLD}=== Uninstall ===${NC}"
    echo -ne "  ${RED}Type 'yes' to confirm: ${NC}"; read -r c
    [ "$c" != "yes" ] && { echo -e "  ${GREEN}Cancelled${NC}"; read -p "  Press Enter..."; return; }
    systemctl stop "$SERVICE_NAME" 2>/dev/null
    systemctl disable "$SERVICE_NAME" 2>/dev/null
    rm -f /etc/systemd/system/${SERVICE_NAME}.service
    rm -f /usr/local/bin/dnstt-failover
    rm -f /usr/local/bin/winnet-dnstt
    echo -ne "  ${YELLOW}Remove config? (y/n): ${NC}"; read -r rc
    [ "$rc" = "y" ] && rm -rf /etc/dnstt-DNS-changer
    systemctl daemon-reload 2>/dev/null
    echo ""
    echo -e "  ${GREEN}✓ Uninstalled${NC}"
    echo -e "  ${GRAY}Note: /root/dnstt-client-linux-amd64 and /root/pub.key were NOT removed${NC}"
    exit 0
}

check_root
while true; do
    show_banner; show_status_bar; show_menu; read -r choice; echo -e "${NC}"
    case $choice in
        1) opt_status ;; 2) opt_start ;; 3) opt_stop ;; 4) opt_restart ;;
        5) opt_logs ;; 6) opt_switches ;; 7) opt_edit ;; 8) opt_test ;;
        9) opt_showconf ;; 10) opt_uninstall ;;
        0) echo -e "  ${GREEN}Bye!${NC}"; exit 0 ;;
        *) echo -e "  ${RED}Invalid!${NC}"; sleep 1 ;;
    esac
done
