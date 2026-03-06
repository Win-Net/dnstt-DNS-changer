#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer CLI (winnet-dnstt) v1.4.0
# https://github.com/Win-Net/dnstt-DNS-changer
# ═══════════════════════════════════════════════════════════

VERSION="1.4.0"
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
    DNS_SERVERS=()
    DOMAINS=()
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

show_status_bar() {
    local s=$(get_status)
    [ "$s" = "active" ] && echo -e "  ${WHITE}Service: ${GREEN}● RUNNING${NC}" || echo -e "  ${WHITE}Service: ${RED}● STOPPED${NC}"
    [ ! -f "/root/dnstt-client-linux-amd64" ] && echo -e "  ${RED}⚠ Missing: /root/dnstt-client-linux-amd64${NC}"
    [ ! -f "/root/pub.key" ] && echo -e "  ${RED}⚠ Missing: /root/pub.key${NC}"
    load_config
    local ar=${AUTO_RESTART_ENABLED:-false}
    [ "$ar" = "true" ] && echo -e "  ${WHITE}Auto-Restart: ${GREEN}● ON${NC} (${AUTO_RESTART_CHECK:-20}s)" || echo -e "  ${WHITE}Auto-Restart: ${RED}● OFF${NC}"
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

# ═══ Save config without losing other settings ═══
save_config() {
    local bin="${BINARY:-/root/dnstt-client-linux-amd64}"
    local key="${PUBKEY_FILE:-/root/pub.key}"
    local listen="${LOCAL_LISTEN:-127.0.0.1:1080}"
    local proto="${PROTOCOL:-udp}"
    local hci="${HEALTH_CHECK_INTERVAL:-30}"
    local mf="${MAX_FAILURES:-3}"
    local afw="${ALL_FAILED_WAIT:-30}"
    local are="${AUTO_RESTART_ENABLED:-true}"
    local arc="${AUTO_RESTART_CHECK:-20}"
    local arm="${AUTO_RESTART_MAX_TRIES:-3}"
    local ste="${SOCKS_TEST_ENABLED:-false}"
    local stu="${SOCKS_TEST_URL:-http://www.google.com}"
    local stt="${SOCKS_TEST_TIMEOUT:-15}"

    cat > "$CONFIG_FILE" << EOF
# DNSTT-DNS-Changer Configuration
# Updated: $(date)

DNS_SERVERS=(
$(for s in "${DNS_SERVERS[@]}"; do echo "    \"$s\""; done)
)

DOMAINS=(
$(for d in "${DOMAINS[@]}"; do echo "    \"$d\""; done)
)

BINARY="$bin"
PUBKEY_FILE="$key"
LOCAL_LISTEN="$listen"
PROTOCOL="$proto"
HEALTH_CHECK_INTERVAL=$hci
MAX_FAILURES=$mf
ALL_FAILED_WAIT=$afw
AUTO_RESTART_ENABLED=$are
AUTO_RESTART_CHECK=$arc
AUTO_RESTART_MAX_TRIES=$arm
SOCKS_TEST_ENABLED=$ste
SOCKS_TEST_URL="$stu"
SOCKS_TEST_TIMEOUT=$stt
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
        local sw=$(journalctl -u "$SERVICE_NAME" --no-pager 2>/dev/null | grep -c "SWITCH" 2>/dev/null)
        local rs=$(journalctl -u "$SERVICE_NAME" --no-pager 2>/dev/null | grep -c "RESTART" 2>/dev/null)
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
    echo -e "  ${WHITE}${BOLD}=== Switch & Restart History ===${NC}"
    echo ""
    local logs=$(journalctl -u "$SERVICE_NAME" --no-pager 2>/dev/null | grep -E "SWITCH|RESTART")
    if [ -z "$logs" ]; then
        echo -e "  ${GRAY}No events yet.${NC}"
    else
        echo "$logs" | tail -30 | while IFS= read -r l; do
            if echo "$l" | grep -q "SWITCH"; then echo -e "  ${PURPLE}🔀 $l${NC}"
            else echo -e "  ${CYAN}🔄 $l${NC}"; fi
        done
        echo ""
        echo -e "  ${WHITE}Switches: ${CYAN}$(echo "$logs" | grep -c SWITCH)${NC} | ${WHITE}Restarts: ${CYAN}$(echo "$logs" | grep -c RESTART)${NC}"
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
    echo -e "  ${WHITE}Files:${NC}"
    [ -f "/root/dnstt-client-linux-amd64" ] && echo -e "    ${GREEN}✓ dnstt-client${NC}" || echo -e "    ${RED}✗ dnstt-client${NC}"
    [ -f "/root/pub.key" ] && echo -e "    ${GREEN}✓ pub.key${NC}" || echo -e "    ${RED}✗ pub.key${NC}"
    echo ""
    load_config
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
    echo -e "  ${WHITE}Servers:${NC}"
    for i in "${!DNS_SERVERS[@]}"; do echo -e "    ${CYAN}[$((i+1))]${NC} ${DNS_SERVERS[$i]} -> ${DOMAINS[$i]}"; done
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

# ═══ ADD DNS - Multiple at once ═══
opt_add_dns() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== Add DNS Servers ===${NC}"
    echo ""

    load_config

    if [ ${#DNS_SERVERS[@]} -gt 0 ]; then
        echo -e "  ${WHITE}Current servers:${NC}"
        for i in "${!DNS_SERVERS[@]}"; do
            echo -e "    ${CYAN}[$((i+1))]${NC} ${DNS_SERVERS[$i]} -> ${DOMAINS[$i]}"
        done
        echo ""
    fi

    echo -e "  ${CYAN}Enter new servers. Press Enter with empty input when done:${NC}"
    echo ""

    local added=0
    local num=$((${#DNS_SERVERS[@]} + 1))

    while true; do
        echo -ne "  ${WHITE}Server $num IP:Port (or Enter to finish): ${NC}"
        read -r new_dns

        # Empty = done
        if [ -z "$new_dns" ]; then
            if [ $added -eq 0 ]; then
                echo -e "  ${YELLOW}No servers added.${NC}"
            fi
            break
        fi

        echo -ne "  ${WHITE}Domain for server $num: ${NC}"
        read -r new_domain

        if [ -z "$new_domain" ]; then
            echo -e "  ${RED}Domain required! Skipping this server.${NC}"
            echo ""
            continue
        fi

        DNS_SERVERS+=("$new_dns")
        DOMAINS+=("$new_domain")
        added=$((added + 1))
        num=$((num + 1))
        echo -e "  ${GREEN}✓ Added: $new_dns -> $new_domain${NC}"
        echo ""
    done

    if [ $added -gt 0 ]; then
        save_config
        echo ""
        echo -e "  ${GREEN}✓ $added server(s) added!${NC}"
        echo ""
        echo -e "  ${WHITE}Updated server list:${NC}"
        for i in "${!DNS_SERVERS[@]}"; do
            echo -e "    ${CYAN}[$((i+1))]${NC} ${DNS_SERVERS[$i]} -> ${DOMAINS[$i]}"
        done
        echo ""
        echo -ne "  ${YELLOW}Restart service? (y/n): ${NC}"; read -r r
        if [ "$r" = "y" ]; then
            systemctl restart "$SERVICE_NAME" 2>/dev/null; sleep 2
            echo -e "  ${GREEN}✓ Restarted${NC}"
        fi
    fi

    read -p "  Press Enter..."
}

# ═══ REMOVE DNS - Select which to remove ═══
opt_remove_dns() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== Remove DNS Server ===${NC}"
    echo ""

    load_config

    if [ ${#DNS_SERVERS[@]} -le 1 ]; then
        echo -e "  ${RED}Cannot remove! Need at least 1 server.${NC}"
        echo ""; read -p "  Press Enter..."; return
    fi

    echo -e "  ${WHITE}Current servers:${NC}"
    echo ""
    for i in "${!DNS_SERVERS[@]}"; do
        echo -e "    ${CYAN}[$((i+1))]${NC} ${DNS_SERVERS[$i]} -> ${DOMAINS[$i]}"
    done
    echo ""
    echo -e "  ${GRAY}Enter number to remove (0 = cancel)${NC}"
    echo -ne "  ${WHITE}Remove #: ${NC}"; read -r rem_num

    if [ -z "$rem_num" ] || [ "$rem_num" = "0" ]; then
        echo -e "  ${GREEN}Cancelled${NC}"
        read -p "  Press Enter..."; return
    fi

    # Validate
    if ! [[ "$rem_num" =~ ^[0-9]+$ ]]; then
        echo -e "  ${RED}Invalid number!${NC}"
        read -p "  Press Enter..."; return
    fi

    local idx=$((rem_num - 1))
    if [ $idx -lt 0 ] || [ $idx -ge ${#DNS_SERVERS[@]} ]; then
        echo -e "  ${RED}Invalid number!${NC}"
        read -p "  Press Enter..."; return
    fi

    local rem_dns="${DNS_SERVERS[$idx]}"
    local rem_domain="${DOMAINS[$idx]}"

    echo ""
    echo -e "  ${YELLOW}Remove this server?${NC}"
    echo -e "    ${WHITE}DNS:${NC}    $rem_dns"
    echo -e "    ${WHITE}Domain:${NC} $rem_domain"
    echo ""
    echo -ne "  ${RED}Confirm? (y/n): ${NC}"; read -r confirm
    if [ "$confirm" != "y" ]; then
        echo -e "  ${GREEN}Cancelled${NC}"
        read -p "  Press Enter..."; return
    fi

    # Build new arrays without the removed item
    local temp_dns=()
    local temp_domains=()
    for i in "${!DNS_SERVERS[@]}"; do
        if [ "$i" -ne "$idx" ]; then
            temp_dns+=("${DNS_SERVERS[$i]}")
            temp_domains+=("${DOMAINS[$i]}")
        fi
    done
    DNS_SERVERS=("${temp_dns[@]}")
    DOMAINS=("${temp_domains[@]}")

    save_config

    echo ""
    echo -e "  ${GREEN}✓ Removed: $rem_dns${NC}"
    echo ""
    echo -e "  ${WHITE}Remaining servers:${NC}"
    for i in "${!DNS_SERVERS[@]}"; do
        echo -e "    ${CYAN}[$((i+1))]${NC} ${DNS_SERVERS[$i]} -> ${DOMAINS[$i]}"
    done
    echo ""
    echo -ne "  ${YELLOW}Restart service? (y/n): ${NC}"; read -r r
    if [ "$r" = "y" ]; then
        systemctl restart "$SERVICE_NAME" 2>/dev/null; sleep 2
        echo -e "  ${GREEN}✓ Restarted${NC}"
    fi
    read -p "  Press Enter..."
}

# ═══ AUTO-RESTART SETTINGS ═══
opt_autorestart() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== Auto-Restart Settings ===${NC}"
    echo ""

    load_config
    local ar=${AUTO_RESTART_ENABLED:-false}
    local ac=${AUTO_RESTART_CHECK:-20}
    local am=${AUTO_RESTART_MAX_TRIES:-3}

    echo -e "  ${WHITE}Current:${NC}"
    [ "$ar" = "true" ] && echo -e "    ${GREEN}● Enabled${NC}" || echo -e "    ${RED}● Disabled${NC}"
    echo -e "    ${WHITE}Check every:${NC}  ${CYAN}${ac}s${NC}"
    echo -e "    ${WHITE}Max tries:${NC}    ${CYAN}${am}${NC}"
    echo ""

    echo -e "    ${CYAN}[1]${NC} Toggle ON/OFF"
    echo -e "    ${CYAN}[2]${NC} Change check interval"
    echo -e "    ${CYAN}[3]${NC} Change max tries"
    echo -e "    ${CYAN}[0]${NC} Back"
    echo ""
    echo -ne "  ${WHITE}Select: ${NC}"; read -r ar_choice

    case $ar_choice in
        1)
            if [ "$ar" = "true" ]; then
                AUTO_RESTART_ENABLED=false
                echo -e "  ${RED}Auto-restart DISABLED${NC}"
            else
                AUTO_RESTART_ENABLED=true
                echo -e "  ${GREEN}Auto-restart ENABLED${NC}"
            fi
            save_config
            ;;
        2)
            echo -ne "  ${WHITE}Seconds [${ac}]: ${NC}"; read -r ni
            if [ -n "$ni" ]; then
                AUTO_RESTART_CHECK=$ni
                save_config
                echo -e "  ${GREEN}✓ Set to ${ni}s${NC}"
            fi
            ;;
        3)
            echo -ne "  ${WHITE}Max tries [${am}]: ${NC}"; read -r nm
            if [ -n "$nm" ]; then
                AUTO_RESTART_MAX_TRIES=$nm
                save_config
                echo -e "  ${GREEN}✓ Set to ${nm}${NC}"
            fi
            ;;
        0) return ;;
    esac

    echo ""
    echo -ne "  ${YELLOW}Restart service? (y/n): ${NC}"; read -r r
    [ "$r" = "y" ] && { systemctl restart "$SERVICE_NAME" 2>/dev/null; sleep 2; echo -e "  ${GREEN}✓ Restarted${NC}"; }
    read -p "  Press Enter..."
}

# ═══ UPDATE ═══
opt_update() {
    show_banner
    echo -e "  ${WHITE}${BOLD}=== Update ===${NC}"
    echo ""
    echo -e "  ${WHITE}Current: ${CYAN}$VERSION${NC}"
    echo -e "  ${GREEN}Config will NOT change${NC}"
    echo ""
    echo -ne "  ${WHITE}Update? (y/n): ${NC}"; read -r u
    [ "$u" != "y" ] && { read -p "  Press Enter..."; return; }

    echo ""
    echo -ne "  ${WHITE}[1/4] Stopping...${NC}        "
    systemctl stop "$SERVICE_NAME" 2>/dev/null; pkill -9 -f "dnstt-client" 2>/dev/null
    echo -e "${GREEN}✓${NC}"

    echo -ne "  ${WHITE}[2/4] Failover...${NC}        "
    curl -sL "$REPO/dnstt-failover.sh" -o /usr/local/bin/dnstt-failover 2>/dev/null && chmod +x /usr/local/bin/dnstt-failover && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"

    echo -ne "  ${WHITE}[3/4] CLI...${NC}             "
    curl -sL "$REPO/dnstt-cli.sh" -o /usr/local/bin/winnet-dnstt 2>/dev/null && chmod +x /usr/local/bin/winnet-dnstt && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"

    echo -ne "  ${WHITE}[4/4] Service...${NC}         "
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
    systemctl daemon-reload
    echo -e "${GREEN}✓${NC}"

    systemctl start "$SERVICE_NAME" 2>/dev/null; sleep 3
    echo ""
    systemctl is-active --quiet "$SERVICE_NAME" && echo -e "  ${GREEN}✓ Running!${NC}" || echo -e "  ${YELLOW}⚠ Check logs${NC}"
    echo -e "  ${YELLOW}Run ${WHITE}winnet-dnstt${YELLOW} again${NC}"
    echo ""; read -p "  Press Enter..."
    exit 0
}

# ═══ UNINSTALL ═══
opt_uninstall() {
    show_banner
    echo -e "  ${RED}${BOLD}=== Uninstall ===${NC}"
    echo -ne "  ${RED}Type 'yes': ${NC}"; read -r c
    [ "$c" != "yes" ] && { echo -e "  ${GREEN}Cancelled${NC}"; read -p "  Press Enter..."; return; }
    systemctl stop "$SERVICE_NAME" 2>/dev/null
    systemctl disable "$SERVICE_NAME" 2>/dev/null
    pkill -9 -f "dnstt-client" 2>/dev/null
    rm -f /etc/systemd/system/${SERVICE_NAME}.service
    rm -f /usr/local/bin/dnstt-failover
    rm -f /usr/local/bin/winnet-dnstt
    echo -ne "  ${YELLOW}Remove config? (y/n): ${NC}"; read -r rc
    [ "$rc" = "y" ] && rm -rf /etc/dnstt-DNS-changer
    systemctl daemon-reload 2>/dev/null
    echo -e "  ${GREEN}✓ Uninstalled${NC}"
    exit 0
}

# ═══ MAIN ═══
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
