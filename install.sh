#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer Installer / Updater v1.4.0
# https://github.com/Win-Net/dnstt-DNS-changer
# ═══════════════════════════════════════════════════════════

set -e
VERSION="1.4.0"
REPO="https://raw.githubusercontent.com/Win-Net/dnstt-DNS-changer/main"
INSTALL_DIR="/etc/dnstt-DNS-changer"
SERVICE="dnstt-DNS-changer"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'

[ "$EUID" -ne 0 ] && { echo -e "${RED}Run as root!${NC}"; exit 1; }

clear
echo -e "${CYAN}"
echo "  ╔═════════════════════════════════════════════╗"
echo "  ║   DNSTT-DNS-Changer v$VERSION                ║"
echo "  ║   github.com/Win-Net/dnstt-DNS-changer     ║"
echo "  ╚═════════════════════════════════════════════╝"
echo -e "${NC}"

# Detect update
IS_UPDATE=false
if [ -f "/usr/local/bin/dnstt-failover" ] || [ -f "/usr/local/bin/winnet-dnstt" ]; then
    IS_UPDATE=true
    echo -e "  ${YELLOW}★ Update mode - config will NOT change${NC}"
    echo ""
    echo -ne "  ${WHITE}Continue? (y/n): ${NC}"; read -r upd
    [ "$upd" != "y" ] && { echo "Cancelled."; exit 0; }
    echo ""
fi

if [ "$IS_UPDATE" = true ]; then
    echo -e "${WHITE}[1/3] Stopping...${NC}"
    systemctl stop "$SERVICE" 2>/dev/null; pkill -9 -f "dnstt-client" 2>/dev/null; sleep 1
    echo -e "  ${GREEN}✓${NC}"

    echo -e "${WHITE}[2/3] Updating...${NC}"
    curl -sL "$REPO/dnstt-failover.sh" -o /usr/local/bin/dnstt-failover && chmod +x /usr/local/bin/dnstt-failover
    curl -sL "$REPO/dnstt-cli.sh" -o /usr/local/bin/winnet-dnstt && chmod +x /usr/local/bin/winnet-dnstt
    # chmod binary
    [ -f "/root/dnstt-client-linux-amd64" ] && chmod +x /root/dnstt-client-linux-amd64
    cat > /etc/systemd/system/${SERVICE}.service << 'SVCEOF'
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
    echo -e "  ${GREEN}✓ Updated${NC}"

    echo -e "${WHITE}[3/3] Starting...${NC}"
    systemctl start "$SERVICE" 2>/dev/null; sleep 3
    systemctl is-active --quiet "$SERVICE" && echo -e "  ${GREEN}✓ Running!${NC}" || echo -e "  ${YELLOW}⚠ winnet-dnstt${NC}"

    echo ""
    echo -e "${GREEN}  ╔═══════════════════════════════╗"
    echo -e "  ║  ✓ Updated to v$VERSION!      ║"
    echo -e "  ║  CLI: ${WHITE}winnet-dnstt${GREEN}            ║"
    echo -e "  ╚═══════════════════════════════╝${NC}"
    exit 0
fi

# ═══ NEW INSTALL ═══

echo -e "${WHITE}[1/6] Dependencies...${NC}"
if command -v apt-get &>/dev/null; then
    apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq curl wget >/dev/null 2>&1
elif command -v yum &>/dev/null; then
    yum install -y -q curl wget >/dev/null 2>&1
fi
echo -e "  ${GREEN}✓${NC}"

echo -e "${WHITE}[2/6] Checking /root/ files...${NC}"
if [ -f "/root/dnstt-client-linux-amd64" ]; then
    chmod +x /root/dnstt-client-linux-amd64
    echo -e "  ${GREEN}✓ dnstt-client found + chmod +x${NC}"
else
    echo -e "  ${RED}✗ dnstt-client NOT found (upload to /root/)${NC}"
fi
[ -f "/root/pub.key" ] && echo -e "  ${GREEN}✓ pub.key found${NC}" || echo -e "  ${RED}✗ pub.key NOT found (upload to /root/)${NC}"

echo -e "${WHITE}[3/6] Config...${NC}"
mkdir -p "$INSTALL_DIR"
SKIP_CONF=false
[ -f "$INSTALL_DIR/config.conf" ] && { echo -ne "  ${YELLOW}Config exists. Overwrite? (y/n): ${NC}"; read -r ow; [ "$ow" != "y" ] && SKIP_CONF=true; }

if [ "$SKIP_CONF" = false ]; then
    echo ""
    echo -e "  ${CYAN}Enter DNS servers. Press Enter with empty input when done:${NC}"
    echo ""
    DNS_L=(); DOM_L=(); N=1
    while true; do
        echo -ne "  ${WHITE}Server $N IP:Port (or Enter to finish): ${NC}"; read -r di
        if [ -z "$di" ]; then
            [ ${#DNS_L[@]} -eq 0 ] && { echo -e "  ${RED}Need at least 1 server!${NC}"; continue; } || break
        fi
        echo -ne "  ${WHITE}Domain for server $N: ${NC}"; read -r dm
        [ -z "$dm" ] && { echo -e "  ${RED}Domain required!${NC}"; continue; }
        DNS_L+=("$di"); DOM_L+=("$dm")
        echo -e "  ${GREEN}✓ Server $N added${NC}"; echo ""; N=$((N+1))
    done

    echo ""
    echo -ne "  ${WHITE}SOCKS5 port [1080]: ${NC}"; read -r sp; sp=${sp:-1080}
    echo -ne "  ${WHITE}Protocol (udp/dot) [udp]: ${NC}"; read -r pr; pr=${pr:-udp}

    cat > "$INSTALL_DIR/config.conf" << CONFEOF
# DNSTT-DNS-Changer Configuration
# Generated: $(date)

DNS_SERVERS=(
$(for s in "${DNS_L[@]}"; do echo "    \"$s\""; done)
)

DOMAINS=(
$(for d in "${DOM_L[@]}"; do echo "    \"$d\""; done)
)

BINARY="/root/dnstt-client-linux-amd64"
PUBKEY_FILE="/root/pub.key"
LOCAL_LISTEN="127.0.0.1:$sp"
PROTOCOL="$pr"
HEALTH_CHECK_INTERVAL=30
MAX_FAILURES=3
ALL_FAILED_WAIT=30
AUTO_RESTART_ENABLED=true
AUTO_RESTART_CHECK=20
AUTO_RESTART_MAX_TRIES=3
SOCKS_TEST_ENABLED=false
SOCKS_TEST_URL="http://www.google.com"
SOCKS_TEST_TIMEOUT=15
CONFEOF
    echo -e "  ${GREEN}✓ Config saved (port: $sp)${NC}"
fi

echo -e "${WHITE}[4/6] Scripts...${NC}"
curl -sL "$REPO/dnstt-failover.sh" -o /usr/local/bin/dnstt-failover && chmod +x /usr/local/bin/dnstt-failover
curl -sL "$REPO/dnstt-cli.sh" -o /usr/local/bin/winnet-dnstt && chmod +x /usr/local/bin/winnet-dnstt
echo -e "  ${GREEN}✓ Installed${NC}"

echo -e "${WHITE}[5/6] Service...${NC}"
cat > /etc/systemd/system/${SERVICE}.service << 'SVCEOF'
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
systemctl daemon-reload; systemctl enable "$SERVICE" >/dev/null 2>&1
echo -e "  ${GREEN}✓${NC}"

echo -e "${WHITE}[6/6] Ready!${NC}"
if [ -f "/root/dnstt-client-linux-amd64" ] && [ -f "/root/pub.key" ]; then
    echo -ne "  ${WHITE}Start now? (y/n): ${NC}"; read -r sn
    [ "$sn" = "y" ] && { systemctl start "$SERVICE"; sleep 3; systemctl is-active --quiet "$SERVICE" && echo -e "  ${GREEN}✓ Running!${NC}" || echo -e "  ${YELLOW}⚠ winnet-dnstt${NC}"; }
else
    echo -e "  ${YELLOW}⚠ Upload dnstt-client & pub.key to /root/${NC}"
fi

echo ""
echo -e "${GREEN}  ╔══════════════════════════════════════╗"
echo -e "  ║    ✓ Installation Complete!           ║"
echo -e "  ╠══════════════════════════════════════╣"
echo -e "  ║  CLI: ${WHITE}winnet-dnstt${GREEN}                   ║"
echo -e "  ╠══════════════════════════════════════╣"
echo -e "  ║  ${YELLOW}Files needed in /root/:${GREEN}             ║"
echo -e "  ║  ${WHITE}  dnstt-client-linux-amd64${GREEN}          ║"
echo -e "  ║  ${WHITE}  pub.key${GREEN}                           ║"
echo -e "  ╚══════════════════════════════════════╝${NC}"
echo ""
