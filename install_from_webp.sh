#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
# Prefer binary webp/ tree; fall back to b64 decode via install.sh
if [[ -d "$ROOT/webp/wolfcreek" ]]; then
  python3 - <<PY
from pathlib import Path
import shutil
root = Path("$ROOT") / "webp"
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
  if site=="trustcom" and (Path(docroot)/"client/public").exists():
    for p in sorted(src.glob("*.webp")):
      out=Path(docroot)/"client/public/img/share"/p.name
      out.parent.mkdir(parents=True, exist_ok=True)
      shutil.copy2(p, out)
      count+=1
      print("wrote", out)
print("TOTAL", count)
PY
else
  bash "$ROOT/install.sh"
fi
