#!/bin/bash
# Install TFL Door main fixed + shared-fallback unique cards into WoodLanding
set -euo pipefail
DOC="${DOCROOT:-/var/www/WoodLanding}"
TGZ="${1:-}"
WORKDIR=$(mktemp -d /tmp/tfldoor_combined.XXXXXX)
trap 'rm -rf "$WORKDIR"' EXIT

if [[ -n "$TGZ" && -f "$TGZ" ]]; then
  tar -xzf "$TGZ" -C "$WORKDIR"
  # tarball may have top-level dir
  if [[ -d "$WORKDIR/tfldoor_combined_deploy" ]]; then
    SRC="$WORKDIR/tfldoor_combined_deploy"
  elif [[ -d "$WORKDIR/img_share" ]]; then
    SRC="$WORKDIR"
  else
    SRC=$(find "$WORKDIR" -type d -name img_share -printf '%h\n' | head -1)
  fi
else
  SRC="$(cd "$(dirname "$0")" && pwd)"
fi

echo "DOC=$DOC SRC=$SRC"
mkdir -p "$DOC/img/share" "$DOC/blog/img/share"

# copy share images
if [[ -d "$SRC/img_share" ]]; then
  cp -v "$SRC/img_share/"* "$DOC/img/share/"
fi
if [[ -d "$SRC/blog_share" ]]; then
  cp -v "$SRC/blog_share/"* "$DOC/blog/img/share/"
fi

# ownership
chown -R www-data:www-data "$DOC/img/share" 2>/dev/null || chown -R tfldoorusr:www-data "$DOC/img/share" || true
chown -R www-data:www-data "$DOC/blog/img/share" 2>/dev/null || true
chmod 644 "$DOC/img/share/"* "$DOC/blog/img/share/"* 2>/dev/null || true

python3 - <<'PY'
import os, re, glob
from pathlib import Path
DOC = Path(os.environ.get('DOCROOT', '/var/www/WoodLanding'))
HOST = 'https://www.tfldoor.com'

# page path (URL path without leading slash, '' for home) -> relative image path from host root
PAGE_IMG = {
  # unique fallbacks
  'cabinet-doors': '/img/share/cabinet-doors.webp',
  'homeowners': '/img/share/homeowners.webp',
  'contractors': '/img/share/contractors.webp',
  'designers': '/img/share/designers.webp',
  'architects': '/img/share/architects.webp',
  'kitchen-cabinet-doors': '/img/share/kitchen-cabinet-doors.webp',
  'cabinet-door-styles': '/img/share/cabinet-door-styles.webp',
  'cabinet-fronts': '/img/share/cabinet-fronts.webp',
  'custom-cabinet-doors-online': '/img/share/custom-cabinet-doors-online.webp',
  'custom-glass-cabinet-doors': '/img/share/custom-glass-cabinet-doors.webp',
  'frameless-cabinet-doors': '/img/share/frameless-cabinet-doors.webp',
  'how-to-measure-cabinet-doors': '/img/share/how-to-measure-cabinet-doors.webp',
  'recessed-panel-cabinet-doors': '/img/share/recessed-panel-cabinet-doors.webp',
  'modern-kitchen-cabinets': '/img/share/modern-kitchen-cabinets.webp',
  'popular-kitchen-cabinet-colors': '/img/share/popular-kitchen-cabinet-colors.webp',
  'cabinet-door-specifications': '/img/share/cabinet-door-specifications.webp',
  'how-to-stain-maple': '/img/share/how-to-stain-maple.webp',
  'inset-cabinets-vs-overlay': '/img/share/inset-cabinets-vs-overlay.webp',
  'faq': '/img/share/faq.webp',
  'pricing': '/img/share/pricing.webp',
  # fixed main
  'formica-cabinet-doors': '/img/share/formica-cabinet-doors.webp',
  'laminate-cabinet-doors': '/img/share/laminate-cabinet-doors.webp',
  'colors': '/img/share/colors.webp',
  'quote': '/img/share/quote.webp',
  'nda': '/img/share/tfldoor-og-nda-1200x630.webp',
  'order': '/img/share/cabinet-door-color-visualizer.jpg',
  'blog': '/blog/img/share/blog-card.jpg',
  'newcustomer': '/blog/img/share/new-customers-card.webp',
  'tfl-doors-new-customers': '/blog/img/share/new-customers-card.webp',
}

# brand specs under cabinet-door-specifications/* share parent card
SPEC_IMG = '/img/share/cabinet-door-specifications.webp'

OG_BLOCK_TMPL = '''<meta property="og:image" content="{url}" />
<meta property="og:image:width" content="1200" />
<meta property="og:image:height" content="630" />
<meta property="og:image:type" content="image/webp" />
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:image" content="{url}" />'''

def find_html(slug: str):
  candidates = [
    DOC / f'{slug}.html',
    DOC / slug / 'index.html',
    DOC / f'{slug}/index.html',
  ]
  for c in candidates:
    if c.is_file():
      return c
  return None

def patch_file(path: Path, img_path: str):
  url = HOST + img_path
  text = path.read_text(encoding='utf-8', errors='ignore')
  orig = text
  # replace existing og:image content URLs
  text2 = re.sub(
    r'(property=["\']og:image["\'][^>]*content=["\'])([^"\']+)(["\'])',
    lambda m: m.group(1) + url + m.group(3),
    text, flags=re.I)
  text2 = re.sub(
    r'(content=["\'])([^"\']+)(["\'][^>]*property=["\']og:image["\'])',
    lambda m: m.group(1) + url + m.group(3),
    text2, flags=re.I)
  text2 = re.sub(
    r'(name=["\']twitter:image["\'][^>]*content=["\'])([^"\']+)(["\'])',
    lambda m: m.group(1) + url + m.group(3),
    text2, flags=re.I)
  text2 = re.sub(
    r'(content=["\'])([^"\']+)(["\'][^>]*name=["\']twitter:image["\'])',
    lambda m: m.group(1) + url + m.group(3),
    text2, flags=re.I)
  if 'property="og:image"' not in text2 and "property='og:image'" not in text2:
    block = OG_BLOCK_TMPL.format(url=url)
    # inject after first meta description or after <head>
    if re.search(r'<meta[^>]+name=["\']description["\'][^>]*>', text2, re.I):
      text2 = re.sub(r'(<meta[^>]+name=["\']description["\'][^>]*>)', r'\1\n' + block, text2, count=1, flags=re.I)
    elif re.search(r'<head[^>]*>', text2, re.I):
      text2 = re.sub(r'(<head[^>]*>)', r'\1\n' + block, text2, count=1, flags=re.I)
  if text2 != orig:
    bak = path.with_suffix(path.suffix + '.bak-share')
    if not bak.exists():
      bak.write_text(orig, encoding='utf-8')
    path.write_text(text2, encoding='utf-8')
    return True
  return text2 != orig or url in text2

patched = []
missing = []
for slug, img in PAGE_IMG.items():
  p = find_html(slug)
  if not p:
    missing.append(slug)
    continue
  if patch_file(p, img):
    patched.append(str(p.relative_to(DOC)))
  else:
    patched.append(str(p.relative_to(DOC)) + ' (already or no-op)')

# specs subpages
spec_dir = DOC / 'cabinet-door-specifications'
if spec_dir.is_dir():
  for html in list(spec_dir.rglob('*.html')) + list(spec_dir.rglob('*.htm')):
    if patch_file(html, SPEC_IMG):
      patched.append(str(html.relative_to(DOC)))

print('PATCHED', len(patched))
for x in patched:
  print(' ', x)
if missing:
  print('MISSING_HTML', missing)
PY

echo "DONE files in img/share:"
ls -la "$DOC/img/share" | tail -40
