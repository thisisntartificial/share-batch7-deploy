#!/usr/bin/env python3
"""Build /share/history/ index: scan rows, plus per-site card gallery with site switcher.

Rules:
  - Site switcher (All sites + every host) so the gallery is organized by site
  - Each site block always starts with that site's homepage / index card
  - Gallery uses the newest archived scan's pages (fail/warn/fallback), plus WATCH fetches
"""
import glob
import html
import os
import re
import ssl
import time
import urllib.error
import urllib.request
from urllib.parse import urljoin, urlparse

HIST = "/var/www/monitor.profuctions.com/share/history"
UA = "ProfuctionsShareHistory/1.0"
# Homepages and pages called out beside the scanner fails. Re-read live on each rebuild.
WATCH = [
    "https://family.drughelp.co/",
    "https://googleproductcheck.profuctions.com/",
    "https://crt.frameworkfire.com/",
    "https://www.tflcloset.com/",
    "https://helpme.stopabusingdrugs.com/",
    "https://jokerduel.com/",
    "https://closets.wtf/",
    "https://bustersflooring.com/products/happy-feet-dynamic-fit-big-sur",
]
CTX = ssl.create_default_context()


def stats(path):
    src = open(path, encoding="utf-8", errors="replace").read()
    vals = re.findall(r'class="k">([^<]+)</div><div class="v[^"]*">(\d+)</div>', src)
    return dict(vals)


def key_of(url):
    p = urlparse(url)
    path = p.path.rstrip("/") or "/"
    return (p.netloc.lower(), path)


def is_homepage(url):
    p = urlparse(url)
    path = (p.path or "/").rstrip("/") or "/"
    return path in ("/", "/index", "/index.html", "/index.htm", "/home", "/home.html")


def tag_text(block, label):
    m = re.search(r"<th>\s*" + re.escape(label) + r"\s*</th><td>(.*?)</td>", block, re.S)
    return html.unescape(re.sub(r"<[^>]+>", "", m.group(1))).strip() if m else ""


def scan_pages(src, statuses=None):
    """Pull page-detail blocks from an archived scan HTML.

    statuses: set of pill classes to include, e.g. {"fail","warn","fallback"}.
    None = include every page-detail that has a URL.
    """
    out = []
    for block in src.split('<details class="page-detail"')[1:]:
        pill_m = re.search(r'class="pill\s+(\w+)"', block[:600])
        status = pill_m.group(1) if pill_m else "unknown"
        if statuses is not None and status not in statuses:
            continue
        url_m = re.search(r'class="purl" href="([^"]+)"', block)
        if not url_m:
            continue
        short = re.search(r'class="ishort">([^<]*)', block)
        image = tag_text(block, "og:image") or tag_text(block, "twitter:image")
        images = []
        if image.startswith("http"):
            images.append({"src": image, "label": ""})
        note = html.unescape(short.group(1)).strip() if short else status
        if status and status not in (note or ""):
            note = ("%s — %s" % (status, note)).strip(" —")
        out.append({
            "url": html.unescape(url_m.group(1)),
            "title": tag_text(block, "Title") or tag_text(block, "og:title"),
            "images": images,
            "note": note or status,
            "kind": "scan",
            "status": status,
            "home": False,
        })
    return out


def fail_pages(src):
    # Back-compat name used by older callers; keep as fail-only.
    return scan_pages(src, statuses={"fail"})


def fetch(url, limit=150000):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=12, context=CTX) as resp:
        ctype = resp.headers.get("Content-Type", "")
        final = resp.geturl()
        body = resp.read(limit)
        status = resp.status
    return status, final, ctype, body


def metas(page_url, body):
    text = body.decode("utf-8", "replace")
    found = []
    title_m = re.search(r"<title[^>]*>(.*?)</title>", text, re.I | re.S)
    title = html.unescape(re.sub(r"\s+", " ", title_m.group(1))).strip() if title_m else ""
    twitter_card = ""
    twitter_image = ""
    images = []
    for tag in re.findall(r"<meta\s+[^>]*>", text, re.I):
        attrs = dict((a.lower(), html.unescape(b)) for a, b in re.findall(
            r'([\w:-]+)\s*=\s*["\']([^"\']*)["\']', tag))
        key = (attrs.get("property") or attrs.get("name") or "").lower()
        content = (attrs.get("content") or "").strip()
        if not content:
            continue
        if key == "og:title":
            title = content
        elif key == "og:image":
            images.append(urljoin(page_url, content))
        elif key == "twitter:image":
            twitter_image = urljoin(page_url, content)
        elif key == "twitter:card":
            twitter_card = content
    if twitter_image and twitter_image not in images:
        images.append(twitter_image)
    notes = []
    if not images:
        notes.append("No share image")
    if twitter_card and not twitter_image:
        notes.append("No twitter:image")
    for src in images:
        low = src.lower()
        if any(bit in low for bit in ("favicon", "logo", "apple-touch-icon")):
            notes.append("This file is a logo or icon")
            break
    if not notes and images:
        notes.append("Homepage / index card")
    return title, [{"src": s, "label": ""} for s in images], "; ".join(notes)


def watch_pages(already):
    out = []
    for url in WATCH:
        if key_of(url) in already:
            continue
        try:
            status, final, ctype, body = fetch(url)
        except Exception as exc:
            out.append({
                "url": url, "title": "", "images": [],
                "note": "Page did not load (%s)" % type(exc).__name__,
                "kind": "watch", "status": "watch", "home": is_homepage(url),
            })
            continue
        if "html" not in ctype.lower() and not body.lstrip().lower().startswith(b"<!doctype") and not body.lstrip().lower().startswith(b"<html"):
            out.append({
                "url": url, "title": "", "images": [],
                "note": "Page came back as %s (HTTP %s)" % (ctype.split(";")[0] or "not HTML", status),
                "kind": "watch", "status": "watch", "home": is_homepage(url),
            })
            continue
        title, images, note = metas(final or url, body)
        out.append({
            "url": final or url, "title": title, "images": images, "note": note,
            "kind": "watch", "status": "watch", "home": is_homepage(final or url),
        })
    return out


def ensure_homepages(items):
    """For every host present, make sure a homepage/index entry exists and is marked.

    Prefer an existing homepage from the scan; otherwise live-fetch https://{host}/.
    """
    by_host = {}
    for item in items:
        host = host_of(item["url"])
        by_host.setdefault(host, []).append(item)
        if is_homepage(item["url"]):
            item["home"] = True

    missing = []
    for host, pages in by_host.items():
        if any(p.get("home") or is_homepage(p["url"]) for p in pages):
            continue
        missing.append(host)

    for host in missing:
        # Prefer bare host; www hosts stay as-is.
        candidates = []
        if host.startswith("www."):
            candidates.append("https://%s/" % host)
            candidates.append("https://%s/" % host[4:])
        else:
            candidates.append("https://%s/" % host)
            candidates.append("https://www.%s/" % host)
        fetched = None
        for url in candidates:
            try:
                status, final, ctype, body = fetch(url)
            except Exception as exc:
                last_err = type(exc).__name__
                continue
            if "html" not in ctype.lower() and not body.lstrip().lower().startswith((b"<!doctype", b"<html")):
                continue
            title, images, note = metas(final or url, body)
            fetched = {
                "url": final or url,
                "title": title,
                "images": images,
                "note": note or "Homepage / index card",
                "kind": "home",
                "status": "home",
                "home": True,
            }
            break
        if fetched is None:
            fetched = {
                "url": candidates[0],
                "title": "",
                "images": [],
                "note": "Homepage did not load",
                "kind": "home",
                "status": "home",
                "home": True,
            }
        items.append(fetched)
    # Re-mark any that match after fetch
    for item in items:
        if is_homepage(item["url"]):
            item["home"] = True
    return items


def extra_trustcom(items):
    """The homepage publishes a real PNG and a later tag that returns HTML."""
    probe = "https://trustcomsystems.com/og-image.png"
    ok = False
    try:
        status, _final, ctype, _body = fetch(probe, limit=32)
        ok = status == 200 and ctype.lower().startswith("image/")
    except Exception:
        ok = False
    if not ok:
        return
    for item in items:
        if urlparse(item["url"]).netloc.lower().endswith("trustcomsystems.com") and is_homepage(item["url"]):
            srcs = [im["src"] for im in item["images"]]
            if probe not in srcs:
                item["images"].insert(0, {"src": probe, "label": "Also on this page. A later tag points unfurlers at the other file."})
            break


def host_of(url):
    return urlparse(url).netloc.lower() or url


def host_slug(host):
    return re.sub(r"[^a-z0-9]+", "-", host.lower()).strip("-")


def sort_pages(pages):
    """Homepage/index first, then path A–Z."""
    def key(item):
        p = urlparse(item["url"])
        path = p.path.rstrip("/") or "/"
        home = 0 if (item.get("home") or is_homepage(item["url"])) else 1
        return (home, path, item["url"])
    return sorted(pages, key=key)


def render_gallery(items):
    if not items:
        return ""
    order = []
    by = {}
    for item in items:
        host = host_of(item["url"])
        if host not in by:
            order.append(host)
            by[host] = []
        by[host].append(item)

    # Alphabetical hosts, but keep stable
    order = sorted(order, key=lambda h: h.lower())

    # Site switcher
    options = ['<option value="__all__" selected>All sites (%d)</option>' % len(order)]
    chips = ['<button type="button" class="sitechip on" data-site="__all__">All <span class="n">%d</span></button>' % len(order)]
    for host in order:
        n = len(by[host])
        slug = host_slug(host)
        options.append('<option value="%s">%s (%d)</option>' % (
            html.escape(slug, quote=True), html.escape(host), n))
        chips.append(
            '<button type="button" class="sitechip" data-site="%s">%s <span class="n">%d</span></button>'
            % (html.escape(slug, quote=True), html.escape(host), n)
        )

    switcher = (
        '<div class="siteswitch" id="siteswitch">'
        '<label class="sr-only" for="sitepick">Site</label>'
        '<select id="sitepick" aria-label="Switch site">%s</select>'
        '<div class="sitechips" role="list">%s</div>'
        '<p class="switchhint">Pick a site to focus the gallery. Each site always starts with its homepage / index card.</p>'
        '</div>'
    ) % ("".join(options), "".join(chips))

    groups = []
    for host in order:
        pages = sort_pages(by[host])
        slug = host_slug(host)
        pics = []
        bare = []
        for item in pages:
            (pics if item["images"] else bare).append(item)
        chunks = [
            '<section class="siteblock" data-site="%s" id="site-%s">'
            '<h3><a href="#site-%s">%s</a> <span class="site-count">%d pages</span></h3>'
            % (html.escape(slug, quote=True), html.escape(slug, quote=True),
               html.escape(slug, quote=True), html.escape(host), len(pages))
        ]
        if pics:
            chunks.append('<div class="grid">')
            for item in pics:
                home_badge = '<span class="homebadge">index</span>' if (item.get("home") or is_homepage(item["url"])) else ""
                shots = []
                for im in item["images"]:
                    src = im["src"] if im["src"].startswith("https://") else ""
                    label = ('<span class="imlabel">%s</span>' % html.escape(im["label"])) if im["label"] else ""
                    shots.append(
                        '<div class="shot"><img src="%s" alt="" loading="lazy" decoding="async" '
                        'onerror="this.parentElement.classList.add(\'miss\')">%s</div>'
                        '<p class="imurl"><a href="%s">%s</a></p>'
                        % (html.escape(src, quote=True), label, html.escape(src, quote=True), html.escape(src))
                    )
                chunks.append(
                    '<figure class="card%s">%s%s<figcaption><a href="%s">%s</a>'
                    '<b>%s</b><span class="note">%s</span></figcaption></figure>'
                    % (
                        " is-home" if (item.get("home") or is_homepage(item["url"])) else "",
                        home_badge,
                        "".join(shots),
                        html.escape(item["url"], quote=True),
                        html.escape(item["url"]),
                        html.escape(item["title"] or "No title"),
                        html.escape(item["note"]),
                    )
                )
            chunks.append("</div>")
        if bare:
            chunks.append('<ul class="bare">')
            for item in bare:
                home_badge = ' <span class="homebadge">index</span>' if (item.get("home") or is_homepage(item["url"])) else ""
                chunks.append(
                    '<li%s>%s<a href="%s">%s</a> <b>%s</b> <span class="note">%s</span></li>'
                    % (
                        ' class="is-home"' if (item.get("home") or is_homepage(item["url"])) else "",
                        home_badge,
                        html.escape(item["url"], quote=True),
                        html.escape(item["url"]),
                        html.escape(item["title"] or "No title"),
                        html.escape(item["note"]),
                    )
                )
            chunks.append("</ul>")
        chunks.append("</section>")
        groups.append("".join(chunks))

    n_pic = sum(1 for i in items if i["images"])
    n_bare = sum(1 for i in items if not i["images"])
    js = r"""
<script>
(function () {
  var pick = document.getElementById('sitepick');
  var chips = document.querySelectorAll('.sitechip');
  var blocks = document.querySelectorAll('.siteblock');
  function setSite(slug) {
    if (!slug) slug = '__all__';
    if (pick && pick.value !== slug) pick.value = slug;
    chips.forEach(function (c) {
      c.classList.toggle('on', c.getAttribute('data-site') === slug);
    });
    blocks.forEach(function (b) {
      var show = (slug === '__all__') || (b.getAttribute('data-site') === slug);
      b.hidden = !show;
    });
    try {
      if (slug === '__all__') history.replaceState(null, '', location.pathname + location.search);
      else history.replaceState(null, '', '#' + 'site-' + slug);
    } catch (e) {}
  }
  if (pick) pick.addEventListener('change', function () { setSite(pick.value); });
  chips.forEach(function (c) {
    c.addEventListener('click', function () { setSite(c.getAttribute('data-site')); });
  });
  var hash = (location.hash || '').replace(/^#site-/, '');
  if (hash) setSite(hash);
})();
</script>
"""
    return (
        '<section class="now" id="now"><h2>On the cards now</h2>'
        '<p class="sub">%d pages with a picture URL, %d with nothing set, across <b>%d</b> sites. '
        'Use the site switcher to focus one domain. <b>Each site always leads with its homepage / index card.</b> '
        'Broken files show as an empty frame. Rebuilt with the history index.</p>'
        '%s%s%s</section>'
        % (n_pic, n_bare, len(order), switcher, "".join(groups), js)
    )


def gallery_for(newest):
    if not newest or not os.path.isfile(newest):
        return ""
    src = open(newest, encoding="utf-8", errors="replace").read()
    # All flagged/interesting cards from the newest archive (not only hard fails),
    # so the site switcher has the full fleet organized.
    items = scan_pages(src, statuses={"fail", "warn", "fallback"})
    # Also keep any other page-detail blocks that already have an image, lightly.
    seen = {key_of(i["url"]) for i in items}
    for extra in scan_pages(src, statuses=None):
        k = key_of(extra["url"])
        if k in seen:
            continue
        if extra["images"]:
            items.append(extra)
            seen.add(k)
    try:
        for w in watch_pages(seen):
            k = key_of(w["url"])
            if k not in seen:
                items.append(w)
                seen.add(k)
    except Exception as exc:
        items.append({
            "url": "https://monitor.profuctions.com/share/history/",
            "title": "Watch list",
            "images": [],
            "note": "Could not re-read the extra pages (%s)" % type(exc).__name__,
            "kind": "watch", "status": "watch", "home": False,
        })
    try:
        ensure_homepages(items)
    except Exception as exc:
        items.append({
            "url": "https://monitor.profuctions.com/share/history/",
            "title": "Homepages",
            "images": [],
            "note": "Could not fill missing homepage cards (%s)" % type(exc).__name__,
            "kind": "home", "status": "home", "home": False,
        })
    extra_trustcom(items)
    return render_gallery(items)


def main():
    files = sorted(glob.glob(HIST + "/20*.html"), reverse=True)
    rows = []
    for f in files:
        date = os.path.basename(f)[:-5]
        s = stats(f)
        covered = s.get("Passing") or s.get("Covered (unique)") or "—"
        rows.append((date, s.get("Pages scanned", "—"), covered,
                     s.get("Warnings", "—"), s.get("Broken / missing", "—"),
                     s.get("Sites needing attention", "—")))
    trs = "\n".join(
        '<tr><td class="dom"><a href="%s.html">%s</a></td><td class="num">%s</td><td class="num ok">%s</td>'
        '<td class="num warn">%s</td><td class="num bad">%s</td><td class="num warn">%s</td></tr>'
        % (d, d, p, ok, w, br, sa)
        for d, p, ok, w, br, sa in rows)
    now = time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime())
    gallery = gallery_for(files[0] if files else "")
    page = """<!doctype html>
<html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>Share card history — Profuctions monitor</title>
<link rel="icon" href="/favicon.ico">
<link rel="stylesheet" href="/assets/operator-theme.css?v=20260914">
<script src="/assets/nav.js?v=20260914" defer></script>
<style>
.hist-table{max-width:760px}
.hist-table table{min-width:0}
td.ok{color:var(--ok)}td.warn{color:var(--warn)}td.bad{color:var(--fail);font-weight:600}
.now{margin:6px 0 28px}
.siteblock{margin:20px 0 28px;scroll-margin-top:72px}
.siteblock h3{font-size:15px;margin:0 0 10px;display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.siteblock h3 a{color:inherit;text-decoration:none}
.siteblock h3 a:hover{text-decoration:underline}
.site-count{font-weight:500;color:var(--ink-2);font-size:12px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:12px}
figure.card{margin:0;background:var(--bg-raise);border:1px solid var(--line);border-radius:var(--radius);overflow:hidden;position:relative}
figure.card.is-home{border-color:var(--ok);box-shadow:0 0 0 1px color-mix(in srgb, var(--ok) 35%%, transparent)}
.homebadge{position:absolute;z-index:2;top:8px;left:8px;background:var(--ok);color:#0b0b0b;font-size:10px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;padding:2px 7px;border-radius:999px}
.shot{aspect-ratio:1200/630;background:#141414;display:flex;align-items:center;justify-content:center;position:relative}
.shot img{width:100%%;height:100%%;object-fit:contain;background:#141414}
.shot.miss img{visibility:hidden}
.shot.miss::after{content:"Does not load as an image";position:absolute;color:#c8c2b4;font-size:13px}
.imlabel,.imurl,figure.card figcaption{font-size:12px;line-height:1.35}
.imlabel{display:block;padding:6px 10px 0;color:var(--ink-2)}
.imurl{margin:0;padding:4px 10px 0;word-break:break-all}
figure.card figcaption{padding:8px 10px 10px;display:flex;flex-direction:column;gap:3px}
figure.card figcaption a{word-break:break-all}
.note{color:var(--warn)}
ul.bare{margin:6px 0 0;padding-left:18px}
ul.bare li{margin:4px 0;font-size:13px;word-break:break-all}
ul.bare li.is-home{list-style:none;margin-left:-6px}
.siteswitch{position:sticky;top:0;z-index:20;background:color-mix(in srgb, var(--bg) 92%%, transparent);backdrop-filter:blur(8px);border:1px solid var(--line);border-radius:var(--radius);padding:10px 12px;margin:0 0 18px}
.siteswitch select{width:min(100%%,420px);font:inherit;padding:8px 10px;border-radius:8px;border:1px solid var(--line);background:var(--bg-raise);color:inherit;margin-bottom:8px}
.sitechips{display:flex;flex-wrap:wrap;gap:6px;max-height:9.5rem;overflow:auto;padding-bottom:2px}
.sitechip{appearance:none;border:1px solid var(--line);background:var(--bg-raise);color:inherit;font:inherit;font-size:12px;padding:5px 9px;border-radius:999px;cursor:pointer}
.sitechip .n{opacity:.7;margin-left:2px}
.sitechip.on{border-color:var(--ok);background:color-mix(in srgb, var(--ok) 18%%, var(--bg-raise));font-weight:600}
.switchhint{margin:8px 0 0;font-size:12px;color:var(--ink-2)}
.sr-only{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);border:0}
</style>
</head>
<body>
<main class="wrap">
<p class="eyebrow">Search</p>
<h1>Share card history</h1>
<p class="sub">Updated <b>%s</b>. %d archived scans. <a href="../">Open the current scan</a></p>
%s
<h2>Past scans</h2>
<div class="tablewrap hist-table"><table>
<thead><tr><th>Scan</th><th>Pages</th><th>Covered</th><th>Warn</th><th>Broken</th><th>Sites flagged</th></tr></thead>
<tbody>%s</tbody></table></div>
<footer>Built by /opt/share-audit/history_index.py after each share-card scan, daily at 12:50 UTC. Gallery is organized by site (switcher up top); each site always starts with its homepage / index card, then the rest of that domain&rsquo;s flagged or imaged pages from the newest archive.</footer>
</main>
</body></html>""" % (now, len(rows), gallery, trs)
    dest = HIST + "/index.html"
    open(dest, "w", encoding="utf-8").write(page)
    print("history index: %d scans, gallery %d bytes, hosts in gallery rebuilt" % (len(rows), len(gallery)))


if __name__ == "__main__":
    main()
