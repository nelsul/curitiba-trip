# Curitiba Trip ✈️🏝️

Our shared trip diary for Curitiba (11–18/11/2026). Everyone signs in with an email code, posts full-quality photos and videos with their location, checks in on the map, likes and comments. Everything merges into one timeline and one map.

Live at **https://viagem.nelsul.com** (only people on the list can sign in).

## What's in here

| Folder | What | Stack |
|---|---|---|
| [`web/`](web) | The web app (mobile-first, works on big screens too) and its media worker | SvelteKit 2 · Svelte 5 · TypeScript · PostgreSQL + Drizzle · Cloudflare R2 · MapLibre · pg-boss + ffmpeg/libvips/exiftool |
| [`ios/`](ios) | Native iOS app (separate, not started yet) | SwiftUI (planned) |

The interface is 100% in Portuguese (pt-BR). Code, comments and commit messages are in English.

## Quick start (web)

You need Node 22+ and Docker.

```bash
cd web
cp .env.example .env      # local-only values, never commit .env
npm install
npm run dev:db            # local Postgres in Docker
npm run db:migrate
npm run dev               # http://localhost:5173
```

Then open **http://localhost:5173/dev-login**. It signs you in as a throwaway test user, works only in dev, and returns 404 in production. More details in [`web/README.md`](web/README.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). In short: branch, keep the cozy-island look, test on a phone-sized screen, open a PR. **Never commit secrets.**
