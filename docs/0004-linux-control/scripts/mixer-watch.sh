#!/bin/sh
seconds=${1:-20}
interval=${2:-0.5}
card=${3:-StealthPedal}
numid=${4:-5}
previous=
end=$(( $(date +%s) + seconds ))
while [ "$(date +%s)" -lt "$end" ]; do
  value=$(amixer -c "$card" cget numid="$numid" | sed -n 's/^ *: values=//p')
  if [ "$value" != "$previous" ]; then
    printf '%s numid=%s values=%s\n' "$(date +%T.%N | cut -c1-12)" "$numid" "$value"
    previous=$value
  fi
  sleep "$interval"
done
printf 'end numid=%s values=%s\n' "$numid" "$previous"
