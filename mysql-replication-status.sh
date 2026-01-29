#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Author : Prashant Dixit
# Version: 1.5 (always print full report + cleaner header formatting)
# Notes  : Shows full sections even when replication is stopped / broken.
# -------------------------------------------------------------------

MYSQL_BIN="${MYSQL_BIN:-/usr/bin/mysql}"

MYSQL_LOGIN_PATH="${MYSQL_LOGIN_PATH:-testadmin_local}"

MYSQL_CNF="${MYSQL_CNF:-/root/.my-shutdown.cnf}"

if [[ -t 1 ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  BLUE=$'\033[0;34m'
  CYAN=$'\033[0;36m'
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RESET=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""; BOLD=""; DIM=""; RESET=""
fi

hr()  { printf "%s\n" "${DIM}----------------------------------------------------------------------${RESET}"; }
hdr() { printf "%s\n" "${BOLD}${CYAN}$*${RESET}"; }
die() { echo "${RED}ERROR:${RESET} $*"; exit 2; }

mysql_run() {
  # Try login-path first, fallback to defaults-file
  local q="$1" out rc
  out="$("$MYSQL_BIN" --login-path="$MYSQL_LOGIN_PATH" -e "$q" 2>&1)" && { echo "$out"; return 0; }
  rc=$?

  if [[ -r "$MYSQL_CNF" ]]; then
    out="$("$MYSQL_BIN" --defaults-file="$MYSQL_CNF" -e "$q" 2>&1)" && { echo "$out"; return 0; }
    rc=$?
    echo "$out"
    return $rc
  fi

  echo "$out"
  return $rc
}

detect_status_cmd() {
  # If SHOW REPLICA STATUS works, use it; else fallback to SLAVE
  if mysql_run "SHOW REPLICA STATUS\\G" | grep -qE '^[[:space:]]*(Replica_IO_State|Source_Host):'; then
    echo "SHOW REPLICA STATUS\\G"
  else
    echo "SHOW SLAVE STATUS\\G"
  fi
}

STATUS_CMD="$(detect_status_cmd)"

# IMPORTANT: Do NOT "|| true" here, because it can hide connection failures.
STATUS_RAW="$(mysql_run "$STATUS_CMD" 2>&1 || true)"

if echo "$STATUS_RAW" | grep -qiE "^(ERROR|mysql:)|Access denied|unknown option|Can't connect|Can't connect to local MySQL server|ERROR [0-9]+"; then
  echo "$STATUS_RAW"
  exit 2
fi

# If not configured as replica, SHOW (REPLICA|SLAVE) STATUS returns empty.
if [[ -z "${STATUS_RAW//[[:space:]]/}" ]]; then
  die "No replica/slave status returned. Is this server configured as a replica?"
fi

get_field() {
  local key="$1"
  echo "$STATUS_RAW" |
    awk -F': ' -v k="$key" '
      {
        gsub(/^[ \t]+|[ \t]+$/, "", $1)
        if ($1 == k) {print $2; found=1; exit}
      }
      END {if (!found) print ""}'
}

Slave_IO_State="$(get_field "Replica_IO_State")"; [[ -n "$Slave_IO_State" ]] || Slave_IO_State="$(get_field "Slave_IO_State")"

Master_Host="$(get_field "Source_Host")"; [[ -n "$Master_Host" ]] || Master_Host="$(get_field "Master_Host")"
Master_User="$(get_field "Source_User")"; [[ -n "$Master_User" ]] || Master_User="$(get_field "Master_User")"
Master_Port="$(get_field "Source_Port")"; [[ -n "$Master_Port" ]] || Master_Port="$(get_field "Master_Port")"

Master_Log_File="$(get_field "Source_Log_File")"; [[ -n "$Master_Log_File" ]] || Master_Log_File="$(get_field "Master_Log_File")"
Read_Master_Log_Pos="$(get_field "Read_Source_Log_Pos")"; [[ -n "$Read_Master_Log_Pos" ]] || Read_Master_Log_Pos="$(get_field "Read_Master_Log_Pos")"

Relay_Log_File="$(get_field "Relay_Log_File")"
Relay_Log_Pos="$(get_field "Relay_Log_Pos")"

Relay_Master_Log_File="$(get_field "Relay_Source_Log_File")"
[[ -n "$Relay_Master_Log_File" ]] || Relay_Master_Log_File="$(get_field "Relay_Master_Log_File")"

SQL_Delay="$(get_field "SQL_Delay")"

Slave_IO_Running="$(get_field "Replica_IO_Running")"; [[ -n "$Slave_IO_Running" ]] || Slave_IO_Running="$(get_field "Slave_IO_Running")"
Slave_SQL_Running="$(get_field "Replica_SQL_Running")"; [[ -n "$Slave_SQL_Running" ]] || Slave_SQL_Running="$(get_field "Slave_SQL_Running")"

Slave_SQL_Running_State="$(get_field "Replica_SQL_Running_State")"
[[ -n "$Slave_SQL_Running_State" ]] || Slave_SQL_Running_State="$(get_field "Slave_SQL_Running_State")"

Seconds_Behind_Master="$(get_field "Seconds_Behind_Source")"
[[ -n "$Seconds_Behind_Master" ]] || Seconds_Behind_Master="$(get_field "Seconds_Behind_Master")"

Last_Errno="$(get_field "Last_Errno")"
Last_Error="$(get_field "Last_Error")"

Last_IO_Error="$(get_field "Last_IO_Error")"
Last_IO_Error_Timestamp="$(get_field "Last_IO_Error_Timestamp")"

Last_SQL_Error="$(get_field "Last_SQL_Error")"

fmt_kv() {
  local k="$1" v="${2:-}"
  [[ -n "${v// /}" ]] || v="<blank>"
  printf "%-24s %s\n" "$k" "$v"
}

emph_status() {
  local label="$1"
  local value="${2:-}"
  local norm="${value,,}"

  [[ -n "${value// /}" ]] || value="<blank>"

  if [[ "$norm" == "yes" ]]; then
    printf "%-24s %s\n" "$label" "${GREEN}******* ${value} ******* ---->>> OK${RESET}"
    return 0
  elif [[ "$norm" == "no" ]]; then
    printf "%-24s %s\n" "$label" "${RED}******* ${value} ******* ---->>> PROBLEM${RESET}"
    return 2
  else
    printf "%-24s %s\n" "$label" "${YELLOW}******* ${value} ******* ---->>> UNKNOWN${RESET}"
    return 1
  fi
}

sec_to_min() {
  local s="${1:-}"
  [[ "$s" =~ ^[0-9]+$ ]] || { echo "<blank>"; return; }

  if (( s < 600 )); then
    awk -v sec="$s" 'BEGIN { printf "%.1fm", sec/60 }'
  else
    awk -v sec="$s" 'BEGIN { printf "%dm", int(sec/60) }'
  fi
}

# Compute overall status, but DO NOT stop printing if broken.
overall="OK"
overall_color="$GREEN"

io_rc=0; sql_rc=0
emph_status "Slave_IO_Running" "${Slave_IO_Running:-}"; io_rc=$?
emph_status "Slave_SQL_Running" "${Slave_SQL_Running:-}"; sql_rc=$?

if [[ $io_rc -eq 2 || $sql_rc -eq 2 ]]; then
  overall="CRITICAL"; overall_color="$RED"
elif [[ $io_rc -eq 1 || $sql_rc -eq 1 ]]; then
  overall="WARNING"; overall_color="$YELLOW"
fi

lag_hint="<blank>"
if [[ -n "${Seconds_Behind_Master// /}" ]] && [[ "${Seconds_Behind_Master}" =~ ^[0-9]+$ ]]; then
  lag_min="$(sec_to_min "$Seconds_Behind_Master")"
  if (( Seconds_Behind_Master == 0 )); then
    lag_hint="${GREEN}${lag_min}${RESET}"
  elif (( Seconds_Behind_Master <= 30 )); then
    lag_hint="${YELLOW}${lag_min}${RESET}"
    [[ "$overall" == "OK" ]] && overall="WARNING" && overall_color="$YELLOW"
  else
    lag_hint="${RED}${lag_min}${RESET}"
    overall="CRITICAL"; overall_color="$RED"
  fi
fi

err_hint="<blank>"
if [[ -n "${Last_SQL_Error// /}${Last_IO_Error// /}${Last_Error// /}" ]]; then
  err_hint="${RED}Errors present${RESET}"
  overall="CRITICAL"; overall_color="$RED"
fi

clear 2>/dev/null || true

hdr "MySQL Replication Status Check Utility  ${DIM}(v1.5)${RESET}"
echo "${DIM}Author: Prashant Dixit${RESET}"
hr
printf "%s %s\n" "${BOLD}Host:${RESET}" "$(hostname -f)"
printf "%s %s\n" "${BOLD}Time:${RESET}" "$(date)"
printf "%s %s\n" "${BOLD}Mode:${RESET}" "${STATUS_CMD%%\\G}"
printf "%s %s  %s  %s\n" "${BOLD}Overall:${RESET}" "${overall_color}${BOLD}${overall}${RESET}" "${BOLD}Lag:${RESET} ${lag_hint}" "${err_hint}"
hr
echo

hdr "Replication Topology"
hr
fmt_kv "Slave_IO_State" "${Slave_IO_State:-}"
fmt_kv "Master_Host" "${Master_Host:-}"
fmt_kv "Master_User" "${Master_User:-}"
fmt_kv "Master_Port" "${Master_Port:-}"
echo

hdr "Positions / Relay"
hr
fmt_kv "Master_Log_File" "${Master_Log_File:-}"
fmt_kv "Read_Master_Log_Pos" "${Read_Master_Log_Pos:-}"
fmt_kv "Relay_Log_File" "${Relay_Log_File:-}"
fmt_kv "Relay_Log_Pos" "${Relay_Log_Pos:-}"
fmt_kv "Relay_Master_Log_File" "${Relay_Master_Log_File:-}"
fmt_kv "SQL_Delay" "${SQL_Delay:-}"
echo

hdr "Thread Status"
hr
# NOTE: do not call emph_status early if you want the report even when stopped.
emph_status "Slave_IO_Running" "${Slave_IO_Running:-}"
emph_status "Slave_SQL_Running" "${Slave_SQL_Running:-}"
fmt_kv "Slave_SQL_Running_State" "${Slave_SQL_Running_State:-}"
fmt_kv "Seconds_Behind_Master" "$(sec_to_min "${Seconds_Behind_Master:-}")"
echo

hdr "Errors"
hr
fmt_kv "Last_Errno" "${Last_Errno:-}"
fmt_kv "Last_Error" "${Last_Error:-}"
fmt_kv "Last_IO_Error" "${Last_IO_Error:-}"
fmt_kv "Last_IO_Error_Timestamp" "${Last_IO_Error_Timestamp:-}"
fmt_kv "Last_SQL_Error" "${Last_SQL_Error:-}"
hr
echo

if [[ "$overall" == "OK" ]]; then
  exit 0
elif [[ "$overall" == "WARNING" ]]; then
  exit 1
else
  exit 2
fi
