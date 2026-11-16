#!/bin/bash
# Install TFL Door fallback share cards (28 unique) + quote-v2 + formica meta fix
# DOCROOT: /var/www/WoodLanding (server1)
set -euo pipefail
DOC=/var/www/WoodLanding
TGZ="${1:-}"
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
if [[ -n "$TGZ" && -f "$TGZ" ]]; then
  tar -xzf "$TGZ" -C "$WORKDIR"
  # find webp dir
  SRC=$(find "$WORKDIR" -name 'cabinet-doors.webp' | head -1 | xargs dirname)
else
  echo "usage: $0 pack.tgz" >&2; exit 1
fi
echo "SRC=$SRC"
mkdir -p "$DOC/img/share"
# copy all webp
count=0
for f in "$SRC"/*.webp; do
  bn=$(basename "$f")
  cp -f "$f" "$DOC/img/share/$bn"
  chown www-data:www-data "$DOC/img/share/$bn" 2>/dev/null || chown tfldoorusr:www-data "$DOC/img/share/$bn" || true
  chmod 644 "$DOC/img/share/$bn"
  count=$((count+1))
  echo "OK img/share/$bn ($(stat -c%s "$DOC/img/share/$bn") bytes)"
done
echo "copied $count webp files"

# Meta patch helper: set og:image + twitter:image + width/height on an html file
patch_meta() {
  local html="$1"
  local imgurl="$2"
  [[ -f "$html" ]] || { echo "skip missing $html"; return 0; }
  python3 - "$html" "$imgurl" <<'PY'
import sys, re, pathlib, time, shutil
html_path = pathlib.Path(sys.argv[1])
imgurl = sys.argv[2]
text = html_path.read_text(encoding='utf-8', errors='replace')
bak_dir = pathlib.Path('/root/site-backups/tfldoor-og-meta') / time.strftime('%Y%m%d-%H%M%S')
bak_dir.mkdir(parents=True, exist_ok=True)
shutil.copy2(html_path, bak_dir / html_path.name)
orig = text
# replace existing og:image content
def repl_prop(m):
  return m.group(1) + imgurl + m.group(3)
text2 = re.sub(
  r'(<meta\s+[^>]*property=["\']og:image["\'][^>]*content=["\'])([^"\']+)(["\'])',
  repl_prop, text, flags=re.I)
text2 = re.sub(
  r'(<meta\s+[^>]*content=["\'])([^"\']+)(["\'][^>]*property=["\']og:image["\'])',
  lambda m: m.group(1)+imgurl+m.group(3), text2, flags=re.I)
text2 = re.sub(
  r'(<meta\s+[^>]*name=["\']twitter:image["\'][^>]*content=["\'])([^"\']+)(["\'])',
  repl_prop, text2, flags=re.I)
text2 = re.sub(
  r'(<meta\s+[^>]*content=["\'])([^"\']+)(["\'][^>]*name=["\']twitter:image["\'])',
  lambda m: m.group(1)+imgurl+m.group(3), text2, flags=re.I)
# if no og:image, inject after description or title
if 'og:image' not in text2.lower():
  block = f'''
<meta property="og:image" content="{imgurl}" />
<meta property="og:image:width" content="1200" />
<meta property="og:image:height" content="630" />
<meta property="og:image:type" content="image/webp" />
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:image" content="{imgurl}" />
'''
  m = re.search(r'(<meta\s+[^>]*name=["\']description["\'][^>]*>)', text2, re.I)
  if m:
    text2 = text2[:m.end()] + block + text2[m.end():]
  else:
    text2 = text2.replace('</head>', block + '</head>', 1)
# ensure width/height
if 'og:image:width' not in text2.lower():
  text2 = re.sub(
    r'(<meta\s+[^>]*property=["\']og:image["\'][^>]*>)',
    r'''\1
<meta property="og:image:width" content="1200" />
<meta property="og:image:height" content="630" />''',
    text2, count=1, flags=re.I)
if text2 != orig:
  html_path.write_text(text2, encoding='utf-8')
  print(f'patched {html_path} -> {imgurl}')
else:
  print(f'no change {html_path} (maybe already set)')
PY
}

# Map page path -> slug (relative to DOC)
# Main pages live as DOC/{slug}.html or nested
declare -A MAP=(
  [architects]=architects
  [cabinet-doors]=cabinet-doors
  [cabinet-fronts]=cabinet-fronts
  [cabinet-door-styles]=cabinet-door-styles
  [kitchen-cabinet-doors]=kitchen-cabinet-doors
  [modern-kitchen-cabinets]=modern-kitchen-cabinets
  [frameless-cabinet-doors]=frameless-cabinet-doors
  [recessed-panel-cabinet-doors]=recessed-panel-cabinet-doors
  [custom-glass-cabinet-doors]=custom-glass-cabinet-doors
  [custom-cabinet-doors-online]=custom-cabinet-doors-online
  [homeowners]=homeowners
  [contractors]=contractors
  [designers]=designers
  [how-to-measure-cabinet-doors]=how-to-measure-cabinet-doors
  [how-to-stain-maple]=how-to-stain-maple
  [inset-cabinets-vs-overlay]=inset-cabinets-vs-overlay
  [popular-kitchen-cabinet-colors]=popular-kitchen-cabinet-colors
  [cabinet-door-specifications]=cabinet-door-specifications
)

for page in "${!MAP[@]}"; do
  slug="${MAP[$page]}"
  html="$DOC/${page}.html"
  url="https://www.tfldoor.com/img/share/${slug}.webp"
  patch_meta "$html" "$url"
done

# brand specs under cabinet-door-specifications/
for brand in alvic arauco egger formica funder kronospan panolam roseburg uniboard wilsonart; do
  slug="cabinet-door-specifications-${brand}-tfl-specifications"
  html="$DOC/cabinet-door-specifications/${brand}-tfl-specifications.html"
  # alt locations
  for cand in \
    "$DOC/cabinet-door-specifications/${brand}-tfl-specifications.html" \
    "$DOC/blog/cabinet-door-specifications/${brand}-tfl-specifications.html" \
    "$DOC/${brand}-tfl-specifications.html"; do
    [[ -f "$cand" ]] && html="$cand" && break
  done
  url="https://www.tfldoor.com/img/share/${slug}.webp"
  patch_meta "$html" "$url"
done

# Formica main page — correct path(s)
for cand in \
  "$DOC/blog/manufacturers/formica-cabinet-doors.html" \
  "$DOC/formica-cabinet-doors.html" \
  "$DOC/blog/formica-cabinet-doors.html"; do
  if [[ -f "$cand" ]]; then
    patch_meta "$cand" "https://www.tfldoor.com/img/share/formica-cabinet-doors.webp"
  fi
done

# Quote CF workaround: new path quote-v2.webp
if [[ -f "$DOC/img/share/quote-v2.webp" ]]; then
  for cand in "$DOC/quote.html" "$DOC/blog/quote.html"; do
    [[ -f "$cand" ]] && patch_meta "$cand" "https://www.tfldoor.com/img/share/quote-v2.webp"
  done
fi

echo "=== verify sample ==="
ls -la "$DOC/img/share/cabinet-doors.webp" "$DOC/img/share/homeowners.webp" "$DOC/img/share/quote-v2.webp" 2>/dev/null || true
echo DONE
