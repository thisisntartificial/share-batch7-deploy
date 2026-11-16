#!/bin/bash
set -euo pipefail
echo "TFL Door batch7 quote.webp install"
URL="https://raw.githubusercontent.com/thisisntartificial/share-batch7-deploy/main/webp/tfldoor/quote.webp"
# Main public site is WoodLanding (www.tfldoor.com)
DOC="/var/www/WoodLanding"
if [ ! -d "$DOC" ]; then
  echo "FATAL: $DOC missing" >&2
  ls /var/www/ 2>/dev/null || true
  exit 2
fi
echo "DOCROOT=$DOC"
mkdir -p "$DOC/img/share"
TMP=$(mktemp /tmp/quoteXXXXXX.webp)
curl -fsSL "$URL" -o "$TMP"
python3 -c "b=open('$TMP','rb').read(); assert b[:4]==b'RIFF' and b[8:12]==b'WEBP'; print('webp ok', len(b))"
cp "$TMP" "$DOC/img/share/quote.webp"
chmod 644 "$DOC/img/share/quote.webp"
ls -la "$DOC/img/share/quote.webp"
# optional twin on app.tfldoor.com
if [ -d /var/www/app.tfldoor.com ]; then
  mkdir -p /var/www/app.tfldoor.com/img/share
  cp "$TMP" /var/www/app.tfldoor.com/img/share/quote.webp
  chmod 644 /var/www/app.tfldoor.com/img/share/quote.webp
  echo "also wrote app.tfldoor.com twin"
fi
# light meta: only quote-named html
python3 - <<'PY'
from pathlib import Path
import re
doc = Path("/var/www/WoodLanding")
url = "https://www.tfldoor.com/img/share/quote.webp"
n = 0
for p in list(doc.glob("*.html")) + list(doc.glob("quote/**/*.html")) + list(doc.glob("**/quote*.html")) + list(doc.glob("**/*quote*.html")):
    try:
        rel = str(p.relative_to(doc))
    except Exception:
        rel = str(p)
    if any(x in rel for x in ["backup", "node_modules", ".git"]):
        continue
    try:
        t = p.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        continue
    if "og:image" not in t:
        continue
    # only patch files whose path/name clearly is the quote page
    if "quote" not in p.name.lower() and "quote" not in rel.lower():
        continue
    new = re.sub(
        r'(property=["\']og:image["\']\s+content=["\'])[^"\']+(["\'])',
        rf"\1{url}\2",
        t,
        count=1,
        flags=re.I,
    )
    new = re.sub(
        r'(name=["\']twitter:image["\']\s+content=["\'])[^"\']+(["\'])',
        rf"\1{url}\2",
        new,
        count=1,
        flags=re.I,
    )
    if new != t:
        p.write_text(new, encoding="utf-8")
        n += 1
        print("meta", rel)
print("meta_patched", n)
PY
curl -sI "https://www.tfldoor.com/img/share/quote.webp" | head -8 || true
echo DONE
