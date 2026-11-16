# Share Batch 7 — WebP OG cards (1200x630)

All cards are WebP at exact 1200x630.

## Deploy on server3

```bash
bash install.sh
```

Via Cursor dock:

```
cd /tmp && git clone https://github.com/thisisntartificial/share-batch7-deploy.git && cd share-batch7-deploy && bash install.sh
```

## Meta tags (configure on each page)

```html
<meta property="og:image" content="https://HOST/img/share/SLUG.webp" />
<meta property="og:image:width" content="1200" />
<meta property="og:image:height" content="630" />
<meta property="og:image:type" content="image/webp" />
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:image" content="https://HOST/img/share/SLUG.webp" />
```

### Paths
- chatgps.xyz: img/share/home.webp, insights.webp
- flooring.llc: img/share/*.webp AND og/*.webp
- profuctions.com: img/share/*.webp AND share/*.webp
- trustcomsystems.com: img/share/*.webp (+ client/public if present)
- wolfcreekdesign.com: img/share/{showcase,effects,text,buttons,...}.webp
- tfldoor.com (server1): img/share/quote.webp — needs phone approval

## Verify
curl -sI https://wolfcreekdesign.com/img/share/effects.webp | head -5
