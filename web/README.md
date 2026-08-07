# Afterna marketing site

```bash
npm install
npm run dev
```

## app-ads.txt

[`public/app-ads.txt`](./public/app-ads.txt) must be live at the **root** of the domain you list in AdMob / App Store developer website, e.g.:

- `https://afterna.app/app-ads.txt`
- and/or `https://afterna.ai/app-ads.txt`

Vite copies `public/` to the site root on build. After deploy, verify the URL returns the single line (no HTML wrapper).

See root [README](../README.md) for the full monorepo.
