#!/bin/bash
set -u

domain=${GUEST_DOMAIN:-stealthpedal-ubuntu}
uri=${LIBVIRT_URI:-qemu:///system}
capture=true
if [ "${1:-}" = "--no-capture" ]; then
  capture=false
  shift
fi
command=$1

request=$(python3 -I -c 'import json, sys
print(json.dumps({"execute": "guest-exec", "arguments": {"path": "/bin/sh", "arg": ["-c", sys.argv[1]], "capture-output": sys.argv[2] == "true"}}))' "$command" "$capture")
pid=$(virsh -c "$uri" qemu-agent-command "$domain" "$request" | python3 -I -c 'import json, sys; print(json.load(sys.stdin)["return"]["pid"])')

if [ "$capture" = false ]; then
  echo "$pid"
  exit 0
fi

for _ in $(seq 1 120); do
  status=$(virsh -c "$uri" qemu-agent-command "$domain" "{\"execute\":\"guest-exec-status\",\"arguments\":{\"pid\":$pid}}")
  if printf '%s' "$status" | python3 -I -c 'import json, sys; sys.exit(0 if json.load(sys.stdin)["return"].get("exited") else 1)'; then
    printf '%s' "$status" | python3 -I -c 'import base64, json, sys
result = json.load(sys.stdin)["return"]
sys.stdout.write(base64.b64decode(result.get("out-data", "")).decode(errors="replace"))
sys.stderr.write(base64.b64decode(result.get("err-data", "")).decode(errors="replace"))
sys.exit(result.get("exitcode", 0))'
    exit $?
  fi
  sleep 1
done
echo "guest-exec: timeout waiting for pid $pid" >&2
exit 124
