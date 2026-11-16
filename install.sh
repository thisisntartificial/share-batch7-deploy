#!/bin/bash
set -euo pipefail
export ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
python3 <<'ENDPY'
from pathlib import Path
import base64, os
root = Path(os.environ["ROOT"])
mapping = {
  "chatgps": ("/var/www/chatgps.xyz/public_html", ["img/share"]),
  "flooring": ("/var/www/flooring.llc/public_html", ["img/share", "og"]),
  "profuctions": ("/var/www/profuctions.com/public_html", ["img/share", "share"]),
  "trustcom": ("/var/www/trustcomsystems.com/public_html", ["img/share"]),
  "wolfcreek": ("/var/www/wolfcreekdesign.com/public_html", ["img/share"]),
}
count=0
for site, (docroot, dests) in mapping.items():
  srcdir = root/site
  if not srcdir.exists():
    print("skip missing", site); continue
  if not Path(docroot).exists():
    print("skip missing docroot", docroot); continue
  for b64f in sorted(srcdir.glob("*.webp.b64")):
    name = b64f.name.replace(".webp.b64", ".webp")
    data = base64.b64decode(b64f.read_text())
    for dest in dests:
      outp = Path(docroot)/dest/name
      outp.parent.mkdir(parents=True, exist_ok=True)
      outp.write_bytes(data)
      count += 1
      print(f"wrote {outp} ({len(data)} bytes)")
  if site=="trustcom" and (Path(docroot)/"client/public").exists():
    vite = Path(docroot)/"client/public/img/share"
    for b64f in sorted(srcdir.glob("*.webp.b64")):
      name = b64f.name.replace(".webp.b64", ".webp")
      data = base64.b64decode(b64f.read_text())
      outp = vite/name
      outp.parent.mkdir(parents=True, exist_ok=True)
      outp.write_bytes(data)
      count += 1
      print(f"wrote {outp}")
print("TOTAL", count)
ENDPY
