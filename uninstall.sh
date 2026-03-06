#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
SERVICE="dnstt-DNS-changer"
[ "$EUID" -ne 0 ] && { echo -e "${RED}Run as root!${NC}"; exit 1; }
echo -e "${RED}=== Uninstall DNSTT-DNS-Changer ===${NC}"
echo -ne "${RED}Type 'yes': ${NC}"; read -r c
[ "$c" != "yes" ] && { echo "Cancelled."; exit 0; }
systemctl stop "$SERVICE" 2>/dev/null
systemctl disable "$SERVICE" 2>/dev/null
rm -f /etc/systemd/system/${SERVICE}.service
rm -f /usr/local/bin/dnstt-failover
rm -f /usr/local/bin/winnet-dnstt
echo -ne "${YELLOW}Remove config? (y/n): ${NC}"; read -r r
[ "$r" = "y" ] && rm -rf /etc/dnstt-DNS-changer
systemctl daemon-reload 2>/dev/null
echo -e "${GREEN}✓ Done${NC}"
