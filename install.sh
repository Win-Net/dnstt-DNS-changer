#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer Installer / Updater
# https://github.com/Win-Net/dnstt-DNS-changer
# ═══════════════════════════════════════════════════════════

set -e
VERSION="1.2.0"
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

# ─── Detect: New Install or Update ───
IS_UPDATE=false
if [ -f "/usr/local/bin/dnstt-failover" ] || [ -f "/usr/local/bin/winnet-dnstt" ]; then
    IS_UPDATE=true
    echo -e "  ${YELLOW}★ Existing installation detected!${NC}"
    echo -e "  ${WHITE}  Running in UPDATE mode${NC}"
    echo -e "  ${GREEN}  Your config will NOT be changed${NC}"
    echo ""
    echo -ne "  ${WHITE}Continue update? (y/n): ${NC}"; read -r upd
    [ "$upd" != "y" ] && { echo -e "  ${GREEN}Cancelled.${NC}"; exit 0; }
    echo ""
fi

if [ "$IS_UPDATE" = true ]; then
    # ════════════════════════════════
    # UPDATE MODE
    # ════════════════════════════════
    
    echo -e "${WHITE}[1/3] Stopping service...${NC}"
    systemctl stop "$SERVICE" 2>/dev/null || true
    echo -e "  ${GREEN}✓ Stopped${NC}"

    echo -e "${WHITE}[2/3] Updating scripts...${NC}"
    curl -sL "$REPO/dnstt-failover.sh" -o /usr/local/bin/dnstt-failover
    chmod +x /usr/local/bin/dnstt-failover
    echo -e "  ${GREEN}✓ Failover engine updated${NC}"

    curl -sL "$REPO/dnstt-cli.sh" -o /usr/local/bin/winnet-dnstt
    chmod +x /usr/local/bin/winnet-dnstt
    echo -e "  ${GREEN}✓ CLI tool updated${NC}"

    # Update service file
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
    echo -e "  ${GREEN}✓ Service file updated${NC}"

    echo -e "${WHITE}[3/3] Starting service...${NC}"
    systemctl start "$SERVICE" 2>/dev/null
    sleep 3
    systemctl is-active --quiet "$SERVICE" && echo -e "  ${GREEN}✓ Running!${NC}" || echo -e "  ${YELLOW}⚠ Check: winnet-dnstt${NC}"

    echo ""
    echo -e "${GREEN}  ╔══════════════════════════════════════════════╗"
    echo -e "  ║         ✓ Update Complete! v$VERSION            ║"
    echo -e "  ╠══════════════════════════════════════════════╣"
    echo -e "  ║  ${WHITE}Your config was NOT changed${GREEN}                 ║"
    echo -e "  ║  CLI: ${WHITE}winnet-dnstt${GREEN}                            ║"
    echo -e "  ╚══════════════════════════════════════════════╝${NC}"
    echo ""
    exit 0
fi

# ════════════════════════════════
# NEW INSTALL MODE
# ════════════════════════════════

# [1] Dependencies
echo -e "${WHITE}[1/6] Dependencies...${NC}"
if command -v apt-get &>/dev/null; then
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y -qq curl wget >/dev/null 2>&1
elif command -v yum &>/dev/null; then
    yum install -y -q curl wget >/dev/null 2>&1
fi
echo -e "  ${GREEN}✓ Done${NC}"

# [2] Check files
echo -e "${WHITE}[2/6] Checking files in /root/...${NC}"
if [ -f "/root/dnstt-client-linux-amd64" ]; then
    chmod +x /root/dnstt-client-linux-amd64
    echo -e "  ${GREEN}✓ dnstt-client-linux-amd64 found${NC}"
else
    echo -e "  ${RED}✗ /root/dnstt-client-linux-amd64 NOT found${NC}"
    echo -e "  ${YELLOW}  Upload it to /root/ before starting${NC}"
fi
if [ -f "/root/pub.key" ]; then
    echo -e "  ${GREEN}✓ pub.key found${NC}"
else
    echo -e "  ${RED}✗ /root/pub.key NOT found${NC}"
    echo -e "  ${YELLOW}  Upload it to /root/ before starting${NC}"
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
    echo -e "  ${GREEN}✓ Config saved (SOCKS5 port: $sp)${NC}"
fi

# [4] Scripts
echo -e "${WHITE}[4/6] Installing scripts...${NC}"
curl -sL "$REPO/dnstt-failover.sh" -o /usr/local/bin/dnstt-failover
chmod +x /usr/local/bin/dnstt-failover
echo -e "  ${GREEN}✓ Failover engine${NC}"

curl -sL "$REPO/dnstt-cli.sh" -o /usr/local/bin/winnet-dnstt
chmod +x /usr/local/bin/winnet-dnstt
echo -e "  ${GREEN}✓ CLI (winnet-dnstt)${NC}"

# [5] Service
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
systemctl daemon-reload
systemctl enable "$SERVICE" >/dev/null 2>&1
echo -e "  ${GREEN}✓ Installed${NC}"

# [6] Start
echo -e "${WHITE}[6/6] Ready!${NC}"
if [ -f "/root/dnstt-client-linux-amd64" ] && [ -f "/root/pub.key" ]; then
    echo -ne "  ${WHITE}Start now? (y/n): ${NC}"; read -r sn
    if [ "$sn" = "y" ]; then
        systemctl start "$SERVICE"; sleep 3
        systemctl is-active --quiet "$SERVICE" && echo -e "  ${GREEN}✓ Running!${NC}" || echo -e "  ${YELLOW}⚠ Check: winnet-dnstt${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ Cannot start. Missing files!${NC}"
fi

echo ""
echo -e "${GREEN}  ╔══════════════════════════════════════════════════╗"
echo -e "  ║           ✓ Installation Complete!                ║"
echo -e "  ╠══════════════════════════════════════════════════╣"
echo -e "  ║  CLI:    ${WHITE}winnet-dnstt${GREEN}                            ║"
echo -e "  ║  Config: ${WHITE}nano $INSTALL_DIR/config.conf${GREEN}       ║"
echo -e "  ╠══════════════════════════════════════════════════╣"
echo -e "  ║  ${YELLOW}Make sure these exist in /root/:${GREEN}              ║"
echo -e "  ║  ${WHITE}  dnstt-client-linux-amd64${GREEN}                    ║"
echo -e "  ║  ${WHITE}  pub.key${GREEN}                                     ║"
echo -e "  ╚══════════════════════════════════════════════════╝${NC}"
echo ""
