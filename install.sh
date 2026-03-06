#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer Installer
# https://github.com/Win-Net/dnstt-DNS-changer
# ═══════════════════════════════════════════════════════════

set -e
VERSION="1.0.0"
REPO="https://raw.githubusercontent.com/Win-Net/dnstt-DNS-changer/main"
INSTALL_DIR="/etc/dnstt-DNS-changer"
SERVICE="dnstt-DNS-changer"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'

[ "$EUID" -ne 0 ] && { echo -e "${RED}Run as root!${NC}"; exit 1; }

clear
echo -e "${CYAN}"
echo "  ╔═════════════════════════════════════════════╗"
echo "  ║   DNSTT-DNS-Changer Installer v$VERSION      ║"
echo "  ║   github.com/Win-Net/dnstt-DNS-changer     ║"
echo "  ╚═════════════════════════════════════════════╝"
echo -e "${NC}"

# [1] Dependencies
echo -e "${WHITE}[1/7] Dependencies...${NC}"
if command -v apt-get &>/dev/null; then
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y -qq curl wget >/dev/null 2>&1
elif command -v yum &>/dev/null; then
    yum install -y -q curl wget >/dev/null 2>&1
fi
echo -e "  ${GREEN}✓ Done${NC}"

# [2] Binary
echo -e "${WHITE}[2/7] Checking dnstt-client...${NC}"
if [ -f "/usr/local/bin/dnstt-client" ]; then
    echo -e "  ${GREEN}✓ Found${NC}"
elif [ -f "/root/dnstt-client-linux-amd64" ]; then
    cp /root/dnstt-client-linux-amd64 /usr/local/bin/dnstt-client
    chmod +x /usr/local/bin/dnstt-client
    echo -e "  ${GREEN}✓ Copied${NC}"
elif [ -f "/root/dnstt-client" ]; then
    cp /root/dnstt-client /usr/local/bin/dnstt-client
    chmod +x /usr/local/bin/dnstt-client
    echo -e "  ${GREEN}✓ Copied${NC}"
else
    echo -ne "  ${YELLOW}Not found. Path: ${NC}"; read -r bp
    if [ -f "$bp" ]; then
        cp "$bp" /usr/local/bin/dnstt-client; chmod +x /usr/local/bin/dnstt-client
        echo -e "  ${GREEN}✓ OK${NC}"
    else
        echo -e "  ${RED}✗ Install dnstt-client first!${NC}"; exit 1
    fi
fi

# [3] Key
echo -e "${WHITE}[3/7] Checking pub.key...${NC}"
mkdir -p "$INSTALL_DIR"
if [ -f "$INSTALL_DIR/pub.key" ]; then
    echo -e "  ${GREEN}✓ Found${NC}"
elif [ -f "/root/pub.key" ]; then
    cp /root/pub.key "$INSTALL_DIR/pub.key"
    echo -e "  ${GREEN}✓ Copied${NC}"
else
    echo -ne "  ${YELLOW}Path to pub.key (Enter to skip): ${NC}"; read -r kp
    if [ -n "$kp" ] && [ -f "$kp" ]; then
        cp "$kp" "$INSTALL_DIR/pub.key"; echo -e "  ${GREEN}✓ OK${NC}"
    else
        echo -e "  ${YELLOW}⚠ Add later to $INSTALL_DIR/pub.key${NC}"
    fi
fi

# [4] Config
echo -e "${WHITE}[4/7] Config...${NC}"
SKIP_CONF=false
if [ -f "$INSTALL_DIR/config.conf" ]; then
    echo -ne "  ${YELLOW}Exists. Overwrite? (y/n): ${NC}"; read -r ow
    [ "$ow" != "y" ] && SKIP_CONF=true
fi

if [ "$SKIP_CONF" = false ]; then
    echo -e "  ${CYAN}Enter DNS servers. Type 'done' when finished:${NC}"
    DNS_L=(); DOM_L=(); N=1
    while true; do
        echo -ne "  ${WHITE}Server $N (ip:port): ${NC}"; read -r di
        [ "$di" = "done" ] || [ -z "$di" ] && { [ ${#DNS_L[@]} -eq 0 ] && { echo -e "  ${RED}Need at least 1!${NC}"; continue; } || break; }
        echo -ne "  ${WHITE}Domain: ${NC}"; read -r dm
        [ -z "$dm" ] && { echo -e "  ${RED}Required!${NC}"; continue; }
        DNS_L+=("$di"); DOM_L+=("$dm")
        echo -e "  ${GREEN}✓ Added${NC}"; N=$((N+1))
    done
    echo -ne "  ${WHITE}SOCKS port [1080]: ${NC}"; read -r sp; sp=${sp:-1080}
    echo -ne "  ${WHITE}Protocol (udp/dot) [udp]: ${NC}"; read -r pr; pr=${pr:-udp}

    cat > "$INSTALL_DIR/config.conf" << CONFEOF
DNS_SERVERS=(
$(for s in "${DNS_L[@]}"; do echo "    \"$s\""; done)
)
DOMAINS=(
$(for d in "${DOM_L[@]}"; do echo "    \"$d\""; done)
)
BINARY="/usr/local/bin/dnstt-client"
PUBKEY_FILE="$INSTALL_DIR/pub.key"
LOCAL_LISTEN="127.0.0.1:$sp"
PROTOCOL="$pr"
HEALTH_CHECK_INTERVAL=10
MAX_FAILURES=3
ALL_FAILED_WAIT=30
SOCKS_TEST_ENABLED=true
SOCKS_TEST_URL="http://www.google.com"
SOCKS_TEST_TIMEOUT=10
CONFEOF
    echo -e "  ${GREEN}✓ Created${NC}"
fi

# [5] Scripts
echo -e "${WHITE}[5/7] Installing scripts...${NC}"
curl -sL "$REPO/dnstt-failover.sh" -o /usr/local/bin/dnstt-failover
chmod +x /usr/local/bin/dnstt-failover
echo -e "  ${GREEN}✓ Failover engine${NC}"

curl -sL "$REPO/dnstt-cli.sh" -o /usr/local/bin/winnet-dnstt
chmod +x /usr/local/bin/winnet-dnstt
echo -e "  ${GREEN}✓ CLI (winnet-dnstt)${NC}"

# [6] Service
echo -e "${WHITE}[6/7] Service...${NC}"
cat > /etc/systemd/system/${SERVICE}.service << 'SVCEOF'
[Unit]
Description=DNSTT-DNS-Changer Tunnel Service
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
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
systemctl enable "$SERVICE" >/dev/null 2>&1
echo -e "  ${GREEN}✓ Installed${NC}"

# [7] Start
echo -e "${WHITE}[7/7] Start...${NC}"
echo -ne "  ${WHITE}Start now? (y/n): ${NC}"; read -r sn
if [ "$sn" = "y" ]; then
    systemctl start "$SERVICE"; sleep 3
    systemctl is-active --quiet "$SERVICE" && echo -e "  ${GREEN}✓ Running!${NC}" || echo -e "  ${YELLOW}⚠ Check: winnet-dnstt${NC}"
fi

echo ""
echo -e "${GREEN}  ╔═════════════════════════════════════════════╗"
echo -e "  ║         ✓ Installation Complete!             ║"
echo -e "  ╠═════════════════════════════════════════════╣"
echo -e "  ║  CLI:    ${WHITE}winnet-dnstt${GREEN}                       ║"
echo -e "  ║  Config: ${WHITE}nano $INSTALL_DIR/config.conf${GREEN}  ║"
echo -e "  ╚═════════════════════════════════════════════╝${NC}"
echo ""
