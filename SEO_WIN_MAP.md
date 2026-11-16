# Share Batch 7 — SEO name + which path WINS

All cards are **1200×630 WebP**.  
Rule: **one canonical public URL per page**. Secondary copies exist only for legacy path compatibility.

---

## 1. wolfcreekdesign.com (server3)
**Canonical:** `https://wolfcreekdesign.com/img/share/{slug}.webp`  
**Slugs (showcase pages):**  
`showcase` `effects` `text` `buttons` `sliders` `trackers` `bar` `boxes` `cards` `closets` `doors` `flooring` `fresh` `menus` `next` `page` `phone` `share`

| Page | WINNING og:image |
|------|------------------|
| /showcase | /img/share/showcase.webp |
| /showcase/effects | /img/share/effects.webp |
| /showcase/text | /img/share/text.webp |
| /showcase/buttons | /img/share/buttons.webp |
| /showcase/sliders | /img/share/sliders.webp |
| /showcase/trackers | /img/share/trackers.webp |
| (other showcase/*) | /img/share/{same-slug}.webp |

Status: **files live (HTTP 200 image/webp)**. Meta still needs patch → point og:image + twitter:image here.

---

## 2. chatgps.xyz (server3)
**Canonical:** `https://chatgps.xyz/img/share/{slug}.webp`

| Page | WINNING file |
|------|--------------|
| / (home) | /img/share/home.webp |
| /insights | /img/share/insights.webp |

Status: **files live**. Meta currently logo.svg → replace with these.

---

## 3. flooring.llc (server3)
**Canonical (new):** `https://flooring.llc/img/share/{slug}.webp`  
**Legacy twin (also written):** `https://flooring.llc/og/{slug}.webp`  
Old live meta used `/og/*.png` — **webp at both paths wins** once meta extension is updated.

| Page | WINNING file | Also at |
|------|--------------|---------|
| /about | /img/share/about.webp | /og/about.webp |
| /privacy-policy | /img/share/privacy-policy.webp | /og/privacy-policy.webp |
| /questions-to-ask | /img/share/questions-to-ask.webp | /og/questions-to-ask.webp |
| /reading-a-flooring-quote | /img/share/reading-a-flooring-quote.webp | /og/reading-a-flooring-quote.webp |
| /red-flags | /img/share/red-flags.webp | /og/red-flags.webp |
| /terms | /img/share/terms.webp | /og/terms.webp |

Status: **files live at both paths**. Meta: switch png → webp (or to /img/share/).

---

## 4. profuctions.com (server3)
**Canonical:** `https://profuctions.com/img/share/{slug}.webp`  
**Also written:** `/share/{slug}.webp` (legacy root)

| Page | WINNING file |
|------|--------------|
| experimental | /img/share/experimental.webp |
| google-dorks | /img/share/google-dorks.webp |

Status: **files live**.

---

## 5. trustcomsystems.com (server3) — SEO CARD NAMES
Site historically used **`{keyword}-card.jpg`**.  
Batch 7 writes **both** styles; **meta should win on the `-card.webp` SEO name**.

| Page URL | SEO WINNING name | Also written (monitor slug) |
|----------|------------------|-----------------------------|
| / | home-card.webp | home.webp |
| /about | about-card.webp | about.webp |
| /blog | blog-card.webp | blog.webp |
| /contact | contact-card.webp | contact.webp |
| /los-angeles-aircraft-simulator | aircraft-simulator-card.webp | los-angeles-aircraft-simulator.webp |
| /los-angeles-commercial-cleaning | commercial-cleaning-card.webp | los-angeles-commercial-cleaning.webp |
| /los-angeles-flight-training | flight-training-card.webp | los-angeles-flight-training.webp |
| /los-angeles-notary-public | notary-public-card.webp | los-angeles-notary-public.webp |
| /los-angeles-process-serving | process-serving-card.webp | los-angeles-process-serving.webp |
| /passport-photos | passport-photos-card.webp | passport-photos.webp |

**On disk:**  
- `client/public/img/share/*` (source)  
- `dist/public/img/share/*` (served)  

**Public:** `https://trustcomsystems.com/img/share/home-card.webp` etc. (HTTP 200 verified)

Old `.jpg` still present — leave until meta points at `.webp`; then jpg is dead weight.

Meta patch example:
```
.jpg → .webp
home-card.jpg → home-card.webp
```

---

## 6. tfldoor.com (server1 — needs phone approval)
**Canonical when approved:** `https://tfldoor.com/img/share/quote.webp`  
File ready in pack; not deployed yet.

---

## Meta template (all sites)
```html
<meta property="og:image" content="https://{host}/img/share/{WINNING}.webp" />
<meta property="og:image:width" content="1200" />
<meta property="og:image:height" content="630" />
<meta property="og:image:type" content="image/webp" />
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:image" content="https://{host}/img/share/{WINNING}.webp" />
```
Trustcom: use `*-card.webp` as WINNING.  
Flooring: prefer `/img/share/`; `/og/` is fallback twin.

---

## Pack locations
- Live disk: already written on server3 (see above)
- GitHub: https://github.com/thisisntartificial/share-batch7-deploy (public)
- Drive: fleet_share_b7.tgz id `1QfoK7bGI41Fy8Dm_uY_xn9lx6MmdWzBr`
- Local: `/workspace/artifacts/share_batch7_webp/`
