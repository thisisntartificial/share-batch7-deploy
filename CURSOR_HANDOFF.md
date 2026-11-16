# Share Batch 7 — WebP deploy handoff for Cursor

## Goal
Install batch-7 social share cards as **WebP** at the monitor SAVE paths, and point each page `og:image` / `twitter:image` at them.

Source pack (local to Grok artifacts, also mirrored below):
`/workspace/artifacts/share_batch7_webp/`

## Sites & remote paths (server3 writable)

| Site | Files | Put under |
|------|-------|-----------|
| chatgps.xyz | home.webp, insights.webp | `img/share/` |
| flooring.llc | about, privacy-policy, questions-to-ask, reading-a-flooring-quote, red-flags, terms | `img/share/` **and** `og/` (site currently uses `/og/*.png`) |
| profuctions.com | experimental.webp, google-dorks.webp | `img/share/` **and** `share/` |
| trustcomsystems.com | home, about, blog, contact, los-angeles-*, passport-photos | `img/share/` (also try `client/public/img/share/` if Vite) |
| wolfcreekdesign.com | 18 showcase cards | `img/share/` |
| tfldoor.com | quote.webp | `img/share/` — **server1**, needs phone approval / dock |

## Exact filenames

### chatgps.xyz
- img/share/home.webp
- img/share/insights.webp

### flooring.llc
- img/share/about.webp → also og/about.webp
- img/share/privacy-policy.webp → og/privacy-policy.webp
- img/share/questions-to-ask.webp → og/questions-to-ask.webp
- img/share/reading-a-flooring-quote.webp → og/reading-a-flooring-quote.webp
- img/share/red-flags.webp → og/red-flags.webp
- img/share/terms.webp → og/terms.webp

### profuctions.com
- img/share/experimental.webp + share/experimental.webp
- img/share/google-dorks.webp + share/google-dorks.webp

### trustcomsystems.com
- img/share/home.webp
- img/share/about.webp
- img/share/blog.webp
- img/share/contact.webp
- img/share/los-angeles-aircraft-simulator.webp
- img/share/los-angeles-commercial-cleaning.webp
- img/share/los-angeles-flight-training.webp
- img/share/los-angeles-notary-public.webp
- img/share/los-angeles-process-serving.webp
- img/share/passport-photos.webp

### wolfcreekdesign.com
- img/share/showcase.webp
- img/share/bar.webp
- img/share/boxes.webp
- img/share/buttons.webp
- img/share/cards.webp
- img/share/closets.webp
- img/share/doors.webp
- img/share/effects.webp
- img/share/flooring.webp
- img/share/fresh.webp
- img/share/menus.webp
- img/share/next.webp
- img/share/page.webp
- img/share/phone.webp
- img/share/share.webp
- img/share/sliders.webp
- img/share/text.webp
- img/share/trackers.webp

### tfldoor.com (server1)
- img/share/quote.webp

## Meta tags (configure)

For each page, set absolute URLs preferred:

```html
<meta property="og:image" content="https://{host}/img/share/{slug}.webp" />
<meta property="og:image:width" content="1200" />
<meta property="og:image:height" content="630" />
<meta property="og:image:type" content="image/webp" />
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:image" content="https://{host}/img/share/{slug}.webp" />
```

### flooring.llc note
Currently points at `https://flooring.llc/og/about.png`. Either:
1. Update meta to `/img/share/about.webp`, or
2. Keep `/og/about.webp` and update meta extension png→webp.

### chatgps.xyz note
Currently uses `/img/logo.svg` — replace with `/img/share/home.webp` (and insights page → insights.webp).

### Compatibility
Most crawlers accept WebP for OG now. If a platform fails, also keep a `.jpg` twin at the same path stem.

## Cursor file_put pattern

```
site: wolfcreekdesign.com
path: img/share/effects.webp
base64_content: <file base64>
mkdirs: true
```

Remote servers (server1 tfldoor) need `approval_code` after phone tap.

## Verify

```bash
curl -sI https://wolfcreekdesign.com/img/share/effects.webp | head -5
# expect: content-type: image/webp, 200
curl -sL https://wolfcreekdesign.com/showcase/effects | grep og:image
```

## Deploy order
1. Put all webp files (mkdirs true)
2. Patch meta tags / SEO injectors
3. Bust cache if any CDN
4. Re-scan monitor share
