#!/usr/bin/env bash
set -u

value_or_na() { printf '%s' "${1:-N/A}"; }
get_ip() { hostname -I 2>/dev/null | awk '{print $1}'; }
get_public_ip() { curl -4fsS --max-time 3 https://api.ipify.org 2>/dev/null || true; }
get_virtualization() {
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    systemd-detect-virt 2>/dev/null || true
  else
    printf 'N/A'
  fi
}

if [[ -r /etc/os-release ]]; then . /etc/os-release; fi
mem_total=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
mem_used=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3}')
swap_total=$(free -h 2>/dev/null | awk '/^Swap:/ {print $2}')
swap_used=$(free -h 2>/dev/null | awk '/^Swap:/ {print $3}')

printf '%s\n' 'System Information'
printf '  Executed By: %s\n' "$(id -un 2>/dev/null || true)"
printf '  Hostname: %s\n' "$(hostname 2>/dev/null || true)"
printf '  Server IP: %s\n' "$(value_or_na "$(get_ip)")"
printf '  Public IP: %s\n' "$(value_or_na "$(get_public_ip)")"
printf '  OS Type and Version: %s\n' "${PRETTY_NAME:-N/A}"
printf '  Kernel Version: %s\n' "$(uname -r 2>/dev/null || true)"
printf '  Architecture: %s\n' "$(uname -m 2>/dev/null || true)"
printf '  Virtualization: %s\n' "$(get_virtualization)"
printf '  Server Time: %s\n' "$(date)"
printf '  Timezone: %s\n' "$(timedatectl show --property=Timezone --value 2>/dev/null || date +%Z)"
printf '  Uptime: %s\n' "$(uptime -p 2>/dev/null || true)"
printf '\nResource Usage\n'
printf '  Total Memory: %s\n' "$(value_or_na "$mem_total")"
printf '  Memory Usage: %s / %s\n' "$(value_or_na "$mem_used")" "$(value_or_na "$mem_total")"
printf '  Swap Usage: %s / %s\n' "$(value_or_na "$swap_used")" "$(value_or_na "$swap_total")"
printf '  CPU Cores: %s\n' "$(nproc 2>/dev/null || true)"
