#!/bin/bash
# TFL Door main share cards — fixed 1200x630 pack
# DOCROOT is ALWAYS /var/www/WoodLanding (not app.tfldoor.com)
set -euo pipefail
DOC=/var/www/WoodLanding
SHARE="$DOC/img/share"
BSHARE="$DOC/blog/img/share"
mkdir -p "$SHARE" "$BSHARE"

# If tarball passed as arg or present next to script
TGZ="${1:-}"
if [[ -z "$TGZ" ]]; then
  for c in /tmp/tfldoor_main_fixed_deploy.tgz ./tfldoor_main_fixed_deploy.tgz /root/tfldoor_main_fixed_deploy.tgz; do
    [[ -f "$c" ]] && TGZ="$c" && break
  done
fi
if [[ -z "${TGZ:-}" || ! -f "$TGZ" ]]; then
  echo "Need tarball path. Usage: $0 /path/to/tfldoor_main_fixed_deploy.tgz"
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
tar -xzf "$TGZ" -C "$TMP"
ls -la "$TMP"

# Install files
install_file() {
  local src="$1" dest="$2"
  if [[ -f "$src" ]]; then
    cp -f "$src" "$dest"
    chown www-data:www-data "$dest" 2>/dev/null || chown tfldoorusr:www-data "$dest" 2>/dev/null || true
    chmod 644 "$dest"
    echo "OK $dest ($(stat -c%s "$dest") bytes)"
  else
    echo "MISSING $src"
  fi
}

install_file "$TMP/formica-cabinet-doors.webp" "$SHARE/formica-cabinet-doors.webp"
install_file "$TMP/laminate-cabinet-doors.webp" "$SHARE/laminate-cabinet-doors.webp"
install_file "$TMP/colors.webp" "$SHARE/colors.webp"
install_file "$TMP/quote.webp" "$SHARE/quote.webp"
install_file "$TMP/blog-card.jpg" "$BSHARE/blog-card.jpg"

# Patch meta: formica, laminate, colors pages
python3 - <<'PY'
from pathlib import Path
import re, shutil
from datetime import datetime

DOC = Path('/var/www/WoodLanding')
bak = Path('/root/site-backups/tfldoor-og-meta') / datetime.utcnow().strftime('%Y%m%d-%H%M%S')
bak.mkdir(parents=True, exist_ok=True)

patches = [
  # (relative html path, old image substring or None, new absolute og url)
  ('formica-cabinet-doors.html', None, 'https://www.tfldoor.com/img/share/formica-cabinet-doors.webp'),
  ('laminate-cabinet-doors.html', None, 'https://www.tfldoor.com/img/share/laminate-cabinet-doors.webp'),
  ('colors.html', None, 'https://www.tfldoor.com/img/share/colors.webp'),
]

# find actual page files
candidates = {
  'formica': list(DOC.glob('**/formica-cabinet-doors*.html')) + list(DOC.glob('formica-cabinet-doors*')),
  'laminate': list(DOC.glob('**/laminate-cabinet-doors*.html')) + list(DOC.glob('laminate-cabinet-doors*')),
  'colors': list(DOC.glob('**/colors.html')) + list(DOC.glob('colors*')),
}
for k,v in candidates.items():
  print(k, [str(p) for p in v[:8]])

def patch_file(path: Path, new_url: str):
  if not path.is_file():
    print('skip missing', path)
    return
  text = path.read_text(encoding='utf-8', errors='replace')
  shutil.copy2(path, bak / path.name)
  # replace og:image and twitter:image content URLs
  def repl_og(m):
    return f'{m.group(1)}{new_url}{m.group(3)}'
  new = re.sub(
    r'(property=["\']og:image["\']\s+content=["\'])([^"\']+)(["\'])',
    repl_og, text, flags=re.I)
  new = re.sub(
    r'(content=["\'])([^"\']+)(["\']\s+property=["\']og:image["\'])',
    lambda m: f'{m.group(1)}{new_url}{m.group(3)}', new, flags=re.I)
  new = re.sub(
    r'(name=["\']twitter:image["\']\s+content=["\'])([^"\']+)(["\'])',
    repl_og, new, flags=re.I)
  new = re.sub(
    r'(content=["\'])([^"\']+)(["\']\s+name=["\']twitter:image["\'])',
    lambda m: f'{m.group(1)}{new_url}{m.group(3)}', new, flags=re.I)
  # if no og:image, inject after description or title
  if 'og:image' not in new.lower():
    inject = (
      f'<meta property="og:image" content="{new_url}" />\n'
      f'<meta property="og:image:width" content="1200" />\n'
      f'<meta property="og:image:height" content="630" />\n'
      f'<meta property="og:image:type" content="image/webp" />\n'
      f'<meta name="twitter:card" content="summary_large_image" />\n'
      f'<meta name="twitter:image" content="{new_url}" />\n'
    )
    new2 = re.sub(r'(</title>)', r'\1\n'+inject, new, count=1, flags=re.I)
    if new2 == new:
      new = inject + new
    else:
      new = new2
  # ensure width/height
  if 'og:image:width' not in new.lower():
    new = re.sub(
      r'(property=["\']og:image["\'][^>]*>)',
      r'\1\n<meta property="og:image:width" content="1200" />\n<meta property="og:image:height" content="630" />',
      new, count=1, flags=re.I)
  if new != text:
    path.write_text(new, encoding='utf-8')
    print('patched', path, '->', new_url)
  else:
    print('no change', path)

# map by slug
for slug, url in [
  ('formica-cabinet-doors', 'https://www.tfldoor.com/img/share/formica-cabinet-doors.webp'),
  ('laminate-cabinet-doors', 'https://www.tfldoor.com/img/share/laminate-cabinet-doors.webp'),
  ('colors', 'https://www.tfldoor.com/img/share/colors.webp'),
]:
  found = []
  for p in DOC.rglob('*'):
    if p.is_file() and slug in p.name and p.suffix in {'.html','.htm',''}:
      if p.suffix == '' and not p.name.endswith(slug):
        continue
      found.append(p)
  # prefer top-level html
  found = sorted(found, key=lambda p: (0 if p.parent==DOC else 1, len(str(p))))
  if not found:
    # try pretty-url directory index
    for cand in [DOC/f'{slug}.html', DOC/slug/'index.html', DOC/'pages'/f'{slug}.html']:
      if cand.is_file():
        found.append(cand)
  print('slug', slug, 'candidates', found[:5])
  if found:
    patch_file(found[0], url)
  else:
    print('WARN no file for', slug)

print('backups in', bak)
PY

echo "=== verify ==="
ls -la "$SHARE"/formica-cabinet-doors.webp "$SHARE"/laminate-cabinet-doors.webp "$SHARE"/colors.webp "$SHARE"/quote.webp "$BSHARE"/blog-card.jpg 2>&1
echo "DONE. Purge CF for https://www.tfldoor.com/img/share/quote.webp (and new files if 404-cached)."
