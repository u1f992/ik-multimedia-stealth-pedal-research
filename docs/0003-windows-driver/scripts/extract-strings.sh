#!/bin/bash
set -eu

driver_dir=$1
out_dir=$2
mkdir -p "$out_dir"
for f in amd64/IKStealthPedalLLx64.sys amd64/IKStealthPedalAPIx64.dll amd64/IKStealthPedalASIOx64.dll amd64/IKStealthPedalASIOx64.exe amd64/IKClsCoInst.dll; do
  name=$(basename "$f")
  { strings -n 5 "$driver_dir/$f"; strings -n 5 -el "$driver_dir/$f"; } | sort -u > "$out_dir/$name.txt"
  echo "$name: $(wc -l < "$out_dir/$name.txt") strings"
done
