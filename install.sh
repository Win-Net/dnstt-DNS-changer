#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer Installer
# https://github.com/Win-Net/dnstt-DNS-changer
# ═══════════════════════════════════════════════════════════

set -e
VERSION="1.1.0"
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
echo -e "${WHITE}[1/6] Dependencies...${NC}"
if command -v apt-get &>/dev/null; then
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y -qq curl wget >/dev/null 2>&1
elif command -v yum &>/dev/null; then
    yum install -y -q curl wget >/dev/null 2>&1
fi
echo -e "  ${GREEN}✓ Done${NC}"

# [2] Check binary and key
echo -e "${WHITE}[2/6] Checking files in /root/...${NC}"
if [ -f "/root/dnstt-client-linux-amd64" ]; then
    chmod +x /root/dnstt-client-linux-amd64
    echo -e "  ${GREEN}✓ dnstt-client-linux-amd64 found${NC}"
else
    echo -e "  ${RED}✗ /root/dnstt-client-linux-amd64 NOT found${NC}"
    echo -e "  ${YELLOW}  You must upload it to /root/ before starting the service${NC}"
fi

if [ -f "/root/pub.key" ]; then
    echo -e "  ${GREEN}✓ pub.key found${NC}"
else
    echo -e "  ${RED}✗ /root/pub.key NOT found${NC}"
    echo -e "  ${YELLOW}  You must upload it to /root/ before starting the service${NC}"
fi

# [3] Config
echo -e "${WHITE}[3/6] Configuration...${NC}"
mkdir -p "$INSTALL_DIR"

SKIP_CONF=false
if [ -f "$INSTALL_DIR/config.conf" ]; then
    echo -ne "  ${YELLOW}Config exists. Overwrite? (y/n): ${NC}"; read -r ow
    [ "$ow" != "y" ] && SKIP_CONF=true
fi

if [ "$SKIP_CONF" = false ]; then
    echo ""
    echo -e "  ${CYAN}Enter DNS servers. Type 'done' when finished:${NC}"
    echo ""
    DNS_L=(); DOM_L=(); N=1
    while true; do
        echo -ne "  ${WHITE}Server $N (ip:port): ${NC}"; read -r di
        [ "$di" = "done" ] || [ -z "$di" ] && { [ ${#DNS_L[@]} -eq 0 ] && { echo -e "  ${RED}Need at least 1!${NC}"; continue; } || break; }
        echo -ne "  ${WHITE}Domain for server $N: ${NC}"; read -r dm
        [ -z "$dm" ] && { echo -e "  ${RED}Required!${NC}"; continue; }
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
SOCKS_TEST_ENABLED=false
SOCKS_TEST_URL="http://www.google.com"
SOCKS_TEST_TIMEOUT=15
CONFEOF
    echo -e "  ${GREEN}✓ Config saved${NC}"
    echo -e "  ${GREEN}✓ SOCKS5 port: $sp${NC}"
fi

# [4] Scripts
echo -e "${WHITE}[4/6] Installing scripts...${NC}"
curl -sL "$REPO/dnstt-failover.sh" -o /usr/local/bin/dnstt-failover
chmod +x /usr/local/bin/dnstt-failover
echo -e "  ${GREEN}✓ Failover engine${NC}"

curl -sL "$REPO/dnstt-cli.sh" -o /usr/local/bin/winnet-dnstt
chmod +x /usr/local/bin/winnet-dnstt
echo -e "  ${GREEN}✓ CLI tool (winnet-dnstt)${NC}"

# [5] Service
echo -e "${WHITE}[5/6] Setting up service...${NC}"
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
systemctl enable "$SERVICE" >/dev/null 2>&1
echo -e "  ${GREEN}✓ Service installed${NC}"

# [6] Start
echo -e "${WHITE}[6/6] Ready!${NC}"

# Check if files exist before offering to start
if [ -f "/root/dnstt-client-linux-amd64" ] && [ -f "/root/pub.key" ]; then
    echo -ne "  ${WHITE}Start service now? (y/n): ${NC}"; read -r sn
    if [ "$sn" = "y" ]; then
        systemctl start "$SERVICE"; sleep 3
        systemctl is-active --quiet "$SERVICE" && echo -e "  ${GREEN}✓ Running!${NC}" || echo -e "  ${YELLOW}⚠ Check: winnet-dnstt${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ Cannot start yet. Missing files!${NC}"
fi

echo ""
echo -e "${GREEN}  ╔══════════════════════════════════════════════════╗"
echo -e "  ║           ✓ Installation Complete!                ║"
echo -e "  ╠══════════════════════════════════════════════════╣"
echo -e "  ║                                                    ║"
echo -e "  ║  CLI command:  ${WHITE}winnet-dnstt${GREEN}                       ║"
echo -e "  ║  Edit config:  ${WHITE}nano $INSTALL_DIR/config.conf${GREEN}  ║"
echo -e "  ║                                                    ║"
echo -e "  ╠══════════════════════════════════════════════════╣"
echo -e "  ║  ${YELLOW}⚠ IMPORTANT: Make sure these files exist:${GREEN}       ║"
echo -e "  ║  ${WHITE}  /root/dnstt-client-linux-amd64${GREEN}                ║"
echo -e "  ║  ${WHITE}  /root/pub.key${GREEN}                                 ║"
echo -e "  ║                                                    ║"
echo -e "  ╚══════════════════════════════════════════════════╝${NC}"
echo ""
