#!/bin/bash
set -u

here=$(dirname "$0")
background=false
if [ "${1:-}" = "--background" ]; then
  background=true
  shift
fi
script=$1
encoded=$(base64 -w0 "$script")
name=$(basename "$script" .py)

if [ "$background" = true ]; then
  "$here/guest-exec.sh" --no-capture "nohup python3 -c \"import base64; exec(base64.b64decode('$encoded'))\" >/tmp/$name.out 2>&1 &"
else
  "$here/guest-exec.sh" "python3 -c \"import base64; exec(base64.b64decode('$encoded'))\""
fi
