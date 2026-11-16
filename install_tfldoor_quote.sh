#!/bin/bash
set -euo pipefail
echo "TFL Door batch7 quote.webp install"
URL="https://raw.githubusercontent.com/thisisntartificial/share-batch7-deploy/main/webp/tfldoor/quote.webp"
DOC=""
if [ -d /var/www/tfldoor.com/public_html ]; then DOC=/var/www/tfldoor.com/public_html
elif [ -d /var/www/www.tfldoor.com/public_html ]; then DOC=/var/www/www.tfldoor.com/public_html
elif [ -d /var/www/tfldoor.com/html ]; then DOC=/var/www/tfldoor.com/html
elif [ -d /var/www/tfldoor.com ]; then DOC=/var/www/tfldoor.com
else
  conf=$(grep -Rsl "tfldoor" /etc/nginx/sites-enabled /etc/nginx/conf.d 2>/dev/null | head -1 || true)
  if [ -n "${conf:-}" ]; then
    DOC=$(grep -E "^\s*root " "$conf" | head -1 | awk '{print $2}' | tr -d ';')
  fi
fi
if [ -z "${DOC:-}" ] || [ ! -d "$DOC" ]; then
  echo "FATAL: could not find tfldoor docroot" >&2
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
# light meta: only if index or quote html exists with og:image
python3 - <<PY
from pathlib import Path
import re
doc = Path("$DOC")
url = "https://www.tfldoor.com/img/share/quote.webp"
n = 0
for p in list(doc.glob("*.html")) + list(doc.glob("quote/**/*.html")) + list(doc.glob("**/quote.html")):
    try:
        t = p.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        continue
    if "og:image" not in t:
        continue
    new = re.sub(
        r'(property=["\']og:image["\']\s+content=["\'])[^"\']+(["\'])',
        rf"\\1{url}\\2",
        t,
        count=1,
        flags=re.I,
    )
    new = re.sub(
        r'(name=["\']twitter:image["\']\s+content=["\'])[^"\']+(["\'])',
        rf"\\1{url}\\2",
        new,
        count=1,
        flags=re.I,
    )
    if new != t:
        p.write_text(new, encoding="utf-8")
        n += 1
        print("meta", p)
print("meta_patched", n)
PY
curl -sI "https://www.tfldoor.com/img/share/quote.webp" | head -8 || true
echo DONE
