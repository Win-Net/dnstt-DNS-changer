#!/bin/bash
# ═══════════════════════════════════════════════════════════
# DNSTT-DNS-Changer Installer / Updater v1.9.0
# https://github.com/Win-Net/dnstt-DNS-changer
# ═══════════════════════════════════════════════════════════

set -e
VERSION="1.9.0"
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
    echo -e "  ${YELLOW}★ Update mode - config safe${NC}"
    echo -ne "  ${WHITE}Continue? (y/n): ${NC}"; read -r upd
    [ "$upd" != "y" ] && exit 0
    echo ""
fi

if [ "$IS_UPDATE" = true ]; then
    echo -e "${WHITE}[1/3] Stopping...${NC}"
    systemctl stop "$SERVICE" 2>/dev/null; pkill -9 -f "dnstt-client" 2>/dev/null; sleep 1
    echo -e "  ${GREEN}✓${NC}"

    echo -e "${WHITE}[2/3] Updating...${NC}"
    curl -sL "$REPO/dnstt-failover.sh" -o /usr/local/bin/dnstt-failover && chmod +x /usr/local/bin/dnstt-failover
    curl -sL "$REPO/dnstt-cli.sh" -o /usr/local/bin/winnet-dnstt && chmod +x /usr/local/bin/winnet-dnstt
    [ -f "/root/dnstt-client-linux-amd64" ] && chmod +x /root/dnstt-client-linux-amd64
    cat > /etc/systemd/system/${SERVICE}.service << 'SVCEOF'
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
    echo -e "  ${GREEN}✓${NC}"

    echo -e "${WHITE}[3/3] Starting...${NC}"
    systemctl start "$SERVICE" 2>/dev/null; sleep 3
    systemctl is-active --quiet "$SERVICE" && echo -e "  ${GREEN}✓ Running!${NC}" || echo -e "  ${YELLOW}⚠ winnet-dnstt${NC}"
    echo ""
    echo -e "${GREEN}  ✓ Updated to v$VERSION | CLI: ${WHITE}winnet-dnstt${NC}"
    exit 0
fi

# ═══ NEW INSTALL ═══

echo -e "${WHITE}[1/7] Dependencies...${NC}"
if command -v apt-get &>/dev/null; then
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y -qq curl wget dnsutils >/dev/null 2>&1
elif command -v yum &>/dev/null; then
    yum install -y -q curl wget bind-utils >/dev/null 2>&1
fi
echo -e "  ${GREEN}✓${NC}"

echo -e "${WHITE}[2/7] Files...${NC}"
if [ -f "/root/dnstt-client-linux-amd64" ]; then
    chmod +x /root/dnstt-client-linux-amd64
    echo -e "  ${GREEN}✓ dnstt-client + chmod${NC}"
else
    echo -e "  ${RED}✗ Upload dnstt-client to /root/${NC}"
fi
[ -f "/root/pub.key" ] && echo -e "  ${GREEN}✓ pub.key${NC}" || echo -e "  ${RED}✗ Upload pub.key to /root/${NC}"

echo -e "${WHITE}[3/7] Downloading config from GitHub...${NC}"
mkdir -p "$INSTALL_DIR"
if [ -f "$INSTALL_DIR/config.conf" ]; then
    echo -ne "  ${YELLOW}Config exists. Overwrite? (y/n): ${NC}"; read -r ow
    if [ "$ow" = "y" ]; then
        curl -sL "$REPO/config.conf" -o "$INSTALL_DIR/config.conf"
        echo -e "  ${GREEN}✓ Downloaded from GitHub${NC}"
    else
        echo -e "  ${GREEN}✓ Kept existing${NC}"
    fi
else
    curl -sL "$REPO/config.conf" -o "$INSTALL_DIR/config.conf"
    echo -e "  ${GREEN}✓ Downloaded from GitHub${NC}"
fi

echo -e "${WHITE}[4/7] Customize config...${NC}"
echo ""
echo -e "  ${CYAN}Enter DNS servers. Empty = done:${NC}"
echo -e "  ${GRAY}(Or press Enter to keep defaults from GitHub)${NC}"
echo ""

DNS_L=(); DOM_L=(); N=1
while true; do
    echo -ne "  ${WHITE}Server $N (ip:port or Enter=done): ${NC}"; read -r di
    if [ -z "$di" ]; then
        break
    fi
    echo -ne "  ${WHITE}Domain: ${NC}"; read -r dm
    [ -z "$dm" ] && { echo -e "  ${RED}Required!${NC}"; continue; }
    DNS_L+=("$di"); DOM_L+=("$dm")
    echo -e "  ${GREEN}✓${NC}"; N=$((N+1))
done

# If user entered servers, update config
if [ ${#DNS_L[@]} -gt 0 ]; then
    echo ""
    echo -ne "  ${WHITE}SOCKS5 port [1080]: ${NC}"; read -r sp; sp=${sp:-1080}
    echo -ne "  ${WHITE}Protocol (udp/dot) [udp]: ${NC}"; read -r pr; pr=${pr:-udp}

    # Read existing config for other values
    source "$INSTALL_DIR/config.conf" 2>/dev/null

    cat > "$INSTALL_DIR/config.conf" << CONFEOF
# DNSTT-DNS-Changer Configuration v1.9.0
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
AUTO_RESTART_CHECK=${AUTO_RESTART_CHECK:-15}
MAX_FAILURES=${MAX_FAILURES:-2}
ALL_FAILED_WAIT=${ALL_FAILED_WAIT:-30}
AUTO_RESTART_ENABLED=${AUTO_RESTART_ENABLED:-true}
AUTO_RESTART_MAX_TRIES=${AUTO_RESTART_MAX_TRIES:-3}
SOCKS_TEST_ENABLED=${SOCKS_TEST_ENABLED:-false}
SOCKS_TEST_URL="${SOCKS_TEST_URL:-http://www.google.com}"
SOCKS_TEST_TIMEOUT=${SOCKS_TEST_TIMEOUT:-15}
CONFEOF
    echo -e "  ${GREEN}✓ Config customized (port: $sp)${NC}"
else
    echo -e "  ${GREEN}✓ Using GitHub defaults${NC}"
fi

echo -e "${WHITE}[5/7] Scripts...${NC}"
curl -sL "$REPO/dnstt-failover.sh" -o /usr/local/bin/dnstt-failover && chmod +x /usr/local/bin/dnstt-failover
curl -sL "$REPO/dnstt-cli.sh" -o /usr/local/bin/winnet-dnstt && chmod +x /usr/local/bin/winnet-dnstt
echo -e "  ${GREEN}✓${NC}"

echo -e "${WHITE}[6/7] Service...${NC}"
cat > /etc/systemd/system/${SERVICE}.service << 'SVCEOF'
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
systemctl daemon-reload; systemctl enable "$SERVICE" >/dev/null 2>&1
echo -e "  ${GREEN}✓${NC}"

echo -e "${WHITE}[7/7] Start...${NC}"
if [ -f "/root/dnstt-client-linux-amd64" ] && [ -f "/root/pub.key" ]; then
    echo -ne "  ${WHITE}Start? (y/n): ${NC}"; read -r sn
    [ "$sn" = "y" ] && { systemctl start "$SERVICE"; sleep 3; systemctl is-active --quiet "$SERVICE" && echo -e "  ${GREEN}✓ Running!${NC}" || echo -e "  ${YELLOW}⚠${NC}"; }
else
    echo -e "  ${YELLOW}Upload files to /root/ first${NC}"
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
