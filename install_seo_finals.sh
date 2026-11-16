#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
export ROOT
python3 <<'PY'
from pathlib import Path
import shutil, os
root = Path(os.environ["ROOT"]) / "webp"
mapping = {
  "chatgps": ("/var/www/chatgps.xyz/public_html", ["img/share"]),
  "flooring": ("/var/www/flooring.llc/public_html", ["img/share", "og"]),
  "profuctions": ("/var/www/profuctions.com/public_html", ["img/share", "share"]),
  "trustcom": ("/var/www/trustcomsystems.com/public_html", ["img/share"]),
  "wolfcreek": ("/var/www/wolfcreekdesign.com/public_html", ["img/share"]),
}
count=0
for site,(docroot,dests) in mapping.items():
  src=root/site
  if not src.exists() or not Path(docroot).exists():
    print("skip", site); continue
  for p in sorted(src.glob("*.webp")):
    for dest in dests:
      out=Path(docroot)/dest/p.name
      out.parent.mkdir(parents=True, exist_ok=True)
      shutil.copy2(p, out)
      count+=1
      print("wrote", out, p.stat().st_size)
  if site=="trustcom":
    for extra in [Path(docroot)/"client/public/img/share", Path(docroot)/"dist/public/img/share"]:
      for p in sorted(src.glob("*.webp")):
        out=extra/p.name
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(p, out)
        count+=1
        print("wrote", out)
print("TOTAL", count)
PY

# Also stage tfldoor payload for server1
if [[ -f "$ROOT/webp/tfldoor/quote.webp" ]]; then
  mkdir -p /tmp/tfldoor-share-ready
  cp -f "$ROOT/webp/tfldoor/quote.webp" /tmp/tfldoor-share-ready/quote.webp
  echo "tfldoor quote staged at /tmp/tfldoor-share-ready/quote.webp"
fi

# Rebuild history index
for f in /opt/share-audit/history_index.py \
         /var/www/monitor.profuctions.com/share/history/../tools/history_index.py \
         /opt/monitor/share/history_index.py; do
  if [[ -f "$f" ]]; then
    echo "Running $f"
    python3 "$f" && break
  fi
done
ls -la /var/www/monitor.profuctions.com/share/history/index.html 2>/dev/null || true
