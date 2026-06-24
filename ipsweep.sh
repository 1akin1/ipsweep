#!/bin/bash

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

OUT="ip.txt"

# ─── Banner ───────────────────────────────────────────────────────────────────
banner() {
  echo -e "${CYAN}${BOLD}"
  echo "--------------------------------------------------------------"
  echo "| IIIIII  PPPPPP   SSSSSSS w    W    W EEEEEEE EEEEEE PPPPPP |"
  echo "|   II    P    P   S       w    W    W E       E      P    P |"
  echo "|   II    P    P   S       W    W    W E       E      P    P |"
  echo "|   II    PPPPP    SSSSSS  w    W    W EEEEEEE EEEEEE PPPPP  |"
  echo "|   II    P             S  W    W    W E       E      P      |"
  echo "|   II    P             S  W    W    W E       E      P      |"
  echo "| IIIIII  P       SSSSSSS  WWWWWWWWWWW EEEEEEE EEEEEE P      |"
  echo "|                                                 -by 1akin1 |"
  echo "--------------------------------------------------------------"
  echo -e "${RESET}"
}

# ─── Usage ────────────────────────────────────────────────────────────────────
usage() {
  echo -e "${BOLD}Usage:${RESET} $0 [-h] [-o output_file] [-t timeout] [-j jobs]"
  echo ""
  echo "  -h            Show this help message"
  echo "  -o FILE       Output file (default: ip.txt)"
  echo "  -t SECONDS    Ping timeout per host (default: 1)"
  echo "  -j JOBS       Max parallel jobs (default: 50)"
  echo ""
}

# ─── Validate IPv4 ────────────────────────────────────────────────────────────
validate_ip() {
  local ip="$1"
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS='.' read -r -a octets <<< "$ip"
  for octet in "${octets[@]}"; do
    # 10# forces base-10 so leading-zero octets (e.g. 08, 010) aren't read as octal
    if (( 10#$octet > 255 )); then
      return 1
    fi
  done
  return 0
}

# ─── Extract network prefix ───────────────────────────────────────────────────
get_prefix() {
  echo "$1" | grep -oE '([0-9]+\.){3}'
}

# ─── Detect this host's primary IPv4 (Linux / macOS / BSD) ─────────────────────
detect_ip() {
  local ip=""
  case "$(uname -s)" in
    Linux)
      # hostname -I lists all addresses, first is usually the primary
      command -v hostname >/dev/null 2>&1 && ip=$(hostname -I 2>/dev/null | awk '{print $1}')
      # Fallback: ask the routing table which source IP reaches the internet
      if [[ -z "$ip" ]] && command -v ip >/dev/null 2>&1; then
        ip=$(ip -4 route get 1.1.1.1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}')
      fi
      ;;
    Darwin|*BSD)
      # ipconfig on the usual interfaces, then ifconfig as a last resort
      command -v ipconfig >/dev/null 2>&1 && ip=$(ipconfig getifaddr en0 2>/dev/null)
      [[ -z "$ip" ]] && command -v ipconfig >/dev/null 2>&1 && ip=$(ipconfig getifaddr en1 2>/dev/null)
      if [[ -z "$ip" ]] && command -v ifconfig >/dev/null 2>&1; then
        ip=$(ifconfig 2>/dev/null | awk '/inet /{print $2}' | grep -v '^127\.' | head -1)
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      # Git Bash / MSYS on Windows. PowerShell gives a locale-independent answer;
      # tr -d '\r' strips the CRLF that Windows tools append.
      if command -v powershell >/dev/null 2>&1; then
        ip=$(powershell.exe -NoProfile -Command \
          "(Get-NetIPConfiguration | Where-Object { \$_.IPv4DefaultGateway -ne \$null } | Select-Object -First 1).IPv4Address.IPAddress" \
          2>/dev/null | tr -d '\r' | head -1)
      fi
      # Fallback: parse Windows ipconfig. "IPv4" is not localized, so grep it, then
      # pull the address off that line (avoids grabbing the subnet mask).
      if [[ -z "$ip" ]] && command -v ipconfig >/dev/null 2>&1; then
        ip=$(ipconfig 2>/dev/null | tr -d '\r' | grep -i 'IPv4' \
             | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | grep -v '^127\.' | head -1)
      fi
      ;;
  esac
  echo "$ip"
}

# ─── Build an OS-appropriate single-ping command ───────────────────────────────
# Linux ping:  -W is timeout in SECONDS.  macOS/BSD ping: -W is in MILLISECONDS,
# while -t is the overall timeout in seconds. Windows ping.exe: -n count, -w is in
# MILLISECONDS. We pick the right flag per OS.
ping_host() {
  local target="$1"
  local timeout="$2"
  case "$(uname -s)" in
    Linux)
      ping -c 1 -W "$timeout" "$target" &>/dev/null
      ;;
    Darwin|*BSD)
      ping -c 1 -t "$timeout" "$target" &>/dev/null
      ;;
    MINGW*|MSYS*|CYGWIN*)
      # Git Bash calls Windows ping.exe. -w wants milliseconds. Grep for TTL=
      # because Windows ping can exit 0 even on "unreachable" replies; a real echo
      # reply always carries a TTL. ("TTL" is not localized in Windows ping output.)
      ping -n 1 -w "$(( timeout * 1000 ))" "$target" 2>/dev/null | grep -qi 'TTL='
      ;;
    *)
      # Unknown OS: plainest possible ping
      ping -c 1 "$target" &>/dev/null
      ;;
  esac
}

# ─── Sweep subnet ─────────────────────────────────────────────────────────────
sweep() {
  local prefix="$1"
  local timeout="$2"
  local max_jobs="$3"
  local active=0

  # Each worker writes its hit into its own file, so parallel writes never collide.
  local tmpdir
  tmpdir=$(mktemp -d)
  # Clean the temp dir up no matter how we exit
  trap 'rm -rf "$tmpdir"' RETURN

  # wait -n (free a single slot when any job finishes) needs Bash 4.3+
  local have_wait_n=0
  if ( wait -n ) 2>/dev/null; then have_wait_n=1; fi

  echo -e "${BOLD}Scanning ${CYAN}${prefix}0/24${RESET} ..."
  echo ""

  local running=0
  for i in $(seq 1 254); do
    local target="${prefix}${i}"
    (
      if ping_host "$target" "$timeout"; then
        echo "$target" > "${tmpdir}/${i}"
        echo -e "  ${GREEN}[+]${RESET} $target is ${GREEN}UP${RESET}"
      fi
    ) &

    (( running++ ))
    if (( running >= max_jobs )); then
      if (( have_wait_n )); then
        wait -n          # block only until ONE job frees a slot (true throttling)
        (( running-- ))
      else
        wait             # older Bash: fall back to draining the whole batch
        running=0
      fi
    fi
  done

  wait  # let any stragglers finish

  # Collate hits, sorted numerically by last octet
  > "$OUT"
  if compgen -G "${tmpdir}/*" >/dev/null; then
    cat "${tmpdir}"/* | sort -t '.' -k4 -n > "$OUT"
    active=$(wc -l < "$OUT" | tr -d ' ')
  fi

  echo ""
  echo -e "${BOLD}---------------------------------------------------${RESET}"
  echo -e " Scan complete. ${GREEN}${active}${RESET} host(s) up on ${CYAN}${prefix}0/24${RESET}"
  echo -e "${BOLD}---------------------------------------------------${RESET}"
}

# ─── Parse flags ──────────────────────────────────────────────────────────────
TIMEOUT=1
MAX_JOBS=50

while getopts "ho:t:j:" opt; do
  case $opt in
    h) banner; usage; exit 0 ;;
    o) OUT="$OPTARG" ;;
    t) TIMEOUT="$OPTARG" ;;
    j) MAX_JOBS="$OPTARG" ;;
    *) usage; exit 1 ;;
  esac
done

# ─── Main ─────────────────────────────────────────────────────────────────────
clear
banner

while true; do
  echo -e "${BOLD}Select an option:${RESET}"
  echo "  1) Auto-detect my IP"
  echo "  2) Enter an IP manually"
  echo "  3) Quit"
  echo ""
  read -rp "$(echo -e "${YELLOW}Choice:${RESET} ")" num

  case $num in
    1)
      address=$(detect_ip)
      if [[ -z "$address" ]]; then
        echo -e "${RED}[!] Could not auto-detect IP address.${RESET}"
        continue
      fi
      prefix=$(get_prefix "$address")
      echo -e "\n  Detected IP: ${CYAN}${address}${RESET}\n"
      break
      ;;
    2)
      read -rp "$(echo -e "${YELLOW}Enter IP address:${RESET} ")" address
      if ! validate_ip "$address"; then
        echo -e "${RED}[!] Invalid IP address: ${address}${RESET}\n"
        continue
      fi
      prefix=$(get_prefix "$address")
      echo -e "\n  Using IP: ${CYAN}${address}${RESET}\n"
      break
      ;;
    3)
      echo "Goodbye."
      exit 0
      ;;
    *)
      echo -e "${RED}[!] Invalid choice. Enter 1, 2, or 3.${RESET}\n"
      ;;
  esac
done

# ─── Confirm and sweep ────────────────────────────────────────────────────────
if [[ -z "$prefix" ]]; then
  echo -e "${RED}[!] Could not determine network prefix. Exiting.${RESET}"
  exit 1
fi

read -rp "$(echo -e "${YELLOW}Start scan on ${prefix}0/24? (Y/N):${RESET} ")" confirm
if [[ ! "$confirm" =~ ^[Yy]([Ee][Ss])?$ ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
sweep "$prefix" "$TIMEOUT" "$MAX_JOBS"

# ─── Save or delete output ────────────────────────────────────────────────────
if [[ -s "$OUT" ]]; then
  echo ""
  read -rp "$(echo -e "${YELLOW}Delete output file '${OUT}'? (Y/N):${RESET} ")" del
  if [[ "$del" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    rm -f "$OUT"
    echo -e "${GREEN}Output file deleted.${RESET}"
  else
    echo -e "Results saved to ${CYAN}${OUT}${RESET}"
  fi
else
  echo -e "${YELLOW}No active hosts found. Nothing saved.${RESET}"
  rm -f "$OUT"
fi