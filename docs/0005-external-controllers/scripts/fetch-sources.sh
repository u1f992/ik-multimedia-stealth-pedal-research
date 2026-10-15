#!/bin/bash
set -eu

here=$(cd "$(dirname "$0")" && pwd)
raw=$here/../raw
scratch=${SCRATCH_DIR:-$here/../../../.tmp/pedal-research}
agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
today=$(date -I)
mkdir -p "$raw" "$scratch"

fetch() {
  curl -sL --http1.1 --max-time 90 -A "$agent" "$1" -o "$2"
}

header() {
  printf 'source: %s\nretrieved: %s\n\n' "$1" "$today"
}

ik_url=https://g1.ikmultimedia.com/html/stealthpedal/download/StealthPedal_CS_User_Manual.pdf
fetch "$ik_url" "$scratch/StealthPedal_CS_User_Manual.pdf"
pdftotext -layout "$scratch/StealthPedal_CS_User_Manual.pdf" "$scratch/StealthPedal_CS_User_Manual.txt"
{
  header "$ik_url"
  awk '/3\.4 Connecting External Expression Pedal and Double Footswitch *$/{f=1} f{print; if (++n >= 108) exit}' "$scratch/StealthPedal_CS_User_Manual.txt"
  printf '\n'
  awk '/EXTERNAL CONTROLLER INPUT/{f=1} f{print} /STATUS INDICATOR/{if (f) exit}' "$scratch/StealthPedal_CS_User_Manual.txt"
} > "$raw/ik-stealthpedal-cs-manual-external-inputs.txt"

empress_url=https://empresseffects.com/blogs/support-zoia/what-expression-pedals-can-i-use
fetch "$empress_url" "$scratch/empress-zoia-exp.html"
{
  header "$empress_url"
  python3 -I - "$scratch/empress-zoia-exp.html" <<'EOF'
import html, re, sys
raw = open(sys.argv[1], encoding="utf-8", errors="replace").read()
body = re.search(r"<article.*?</article>|<main.*?</main>", raw, re.S)
text = body.group(0) if body else raw
text = re.sub(r"<script.*?</script>|<style.*?</style>", "", text, flags=re.S)
text = re.sub(r"<br\s*/?>|</p>|</li>|</h\d>|</tr>", "\n", text)
text = html.unescape(re.sub(r"<[^>]+>", " ", text))
lines = [re.sub(r"\s+", " ", l).strip() for l in text.splitlines()]
print("\n".join(l for l in lines if l))
EOF
} > "$raw/empress-zoia-expression-pedals.txt"

manual_excerpt() {
  url=$1
  name=$2
  pattern=$3
  fetch "$url" "$scratch/$name.pdf"
  pdftotext -layout "$scratch/$name.pdf" "$scratch/$name.txt"
  {
    header "$url"
    grep -n -i -E "$pattern" "$scratch/$name.txt"
  } > "$raw/$name.txt"
}

manual_excerpt https://static.roland.com/assets/media/pdf/FS-6_OM.pdf boss-fs-6-manual \
  'stereo 1/4|mono 1/4|Jack A & B|LATCH|MOMENTARY|POLARITY|OPEN|Accessories|FS-5'
manual_excerpt https://static.roland.com/assets/media/pdf/FS-7_OM.pdf boss-fs-7-manual \
  'stereo 1/4|jack A|jack B|\[MODE\]|\[POLARITY\]|LATCH|MOMENTARY|AC adaptor|Accessories|open'
manual_excerpt https://static.roland.com/assets/media/pdf/EV-30_eng03_W.pdf boss-ev-30-manual \
  'output jack|POLARITY|EXP 1|EXP 2|Stereo cable|Accessories|guarantee'
manual_excerpt https://www.adorama.com/col/productManuals/ROEV5.pdf roland-ev-5-manual \
  'Minimum Volume|Stereo Plug|Cord|Weight'

{
  printf 'sha256  size  retrieved  file\n'
  for f in StealthPedal_CS_User_Manual.pdf empress-zoia-exp.html boss-fs-6-manual.pdf boss-fs-7-manual.pdf boss-ev-30-manual.pdf roland-ev-5-manual.pdf; do
    printf '%s  %s  %s  %s\n' "$(sha256sum "$scratch/$f" | cut -c1-64)" "$(stat -c %s "$scratch/$f")" "$today" "$f"
  done
} > "$raw/sources-sha256.txt"

ls -la "$raw"
