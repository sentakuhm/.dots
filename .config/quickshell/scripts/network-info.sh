#!/usr/bin/env bash
set -u

if ! command -v nmcli >/dev/null 2>&1; then
  printf '{"kind":"offline","name":"NetworkManager missing"}\n'
  exit 0
fi

line=$(nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | awk -F: '$2 == "connected" { print $1 "|" $3; exit }')
if [[ -z "$line" ]]; then
  printf '{"kind":"offline","name":"Disconnected"}\n'
  exit 0
fi
kind=${line%%|*}
name=${line#*|}
case "$kind" in
wifi) label="Wi-Fi" ;;
ethernet) label="Ethernet" ;;
*) label="$kind" ;;
esac
jq -cn --arg kind "$kind" --arg name "$name" --arg label "$label" '{kind:$kind,name:$name,label:$label}'
