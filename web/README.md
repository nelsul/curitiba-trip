# Web app

SvelteKit app (UI + API) plus a background worker for photos and videos.

## How it fits together

```
Browser ──► SvelteKit app (src/) ──► PostgreSQL (Drizzle, migrations in drizzle/)
   │                 │
   │                 └─► pg-boss queue ──► worker (worker/): exiftool, libvips, ffmpeg
   │                                              │
   └── uploads go straight to Cloudflare R2 ◄─────┘ (originals untouched; thumb/medium/display/video derived)
```

- **Login:** pick your name, get a 6-digit code by email. In dev the code is printed in the terminal instead of emailed.
- **Uploads:** the browser uploads in chunks directly to R2 (presigned multipart). GPS and capture time come from the file: in the browser for photos, in the worker for videos.
- **Feed** (`src/routes/(app)/+page.svelte`): Instagram-style, newest first. Photos from the same person within 30 min become a carousel. Likes and comments.
- **Map** (`src/routes/(app)/mapa`): MapLibre with OpenFreeMap tiles, recolored in `src/lib/map-style.ts`. It shows live locations (while the app is open) and check-ins. Each check-in gets a map picture drawn in the browser (`src/lib/map-snapshot.ts`).
- **Roteiro:** the itinerary is static data in `src/lib/itinerary.ts`.
- **Theme:** dark only. Design tokens are in `src/app.css`, and the icons are in `src/lib/components/Icon.svelte`.

## Local development

```bash
cp .env.example .env
npm install
npm run dev:db        # Postgres 17 on localhost:5432 (docker-compose.dev.yml)
npm run db:migrate
npm run dev
```

- Open `http://localhost:5173/dev-login` to sign in as a test user ("Teste").
- Add more local people with `npm run user:add -- "Name" someone@example.com [--admin]`. Then use the real login: the code shows up in the `npm run dev` terminal.
- **Uploads** need an R2 bucket. Create your own free Cloudflare R2 bucket and fill in `R2_*` in `.env`. Its CORS policy must allow `http://localhost:5173` with `GET, PUT, HEAD` and expose `ETag`. Everything else works without R2.
- **Processing photos and videos** needs the worker plus `exiftool`, `vips` and `ffmpeg` on your machine (`npm run worker`). Without it, uploads stay "Processando…".

## Checks

```bash
npm run check   # svelte-check + TypeScript
npm run build   # production build (app + worker bundle)
```

## Database changes

1. Edit `src/lib/server/db/schema.ts`.
2. Run `npm run db:generate -- --name short_description` to create a SQL migration in `drizzle/`.
3. Run `npm run db:migrate` to apply it locally. Production applies migrations automatically when the app starts.

Commit the generated SQL and `drizzle/meta` files.

## Production

Merging into `main` deploys automatically (`.github/workflows/deploy.yml`):

1. CI runs again: `npm ci`, the type check, and the build.
2. A `.env` is written from the **production** environment secrets on GitHub.
3. `web/` is sent to the VPS over SSH and rebuilt with `docker compose up -d --build`. The deploy key on the server can only run that deploy.
4. A smoke test checks that the site responds.

You can also re-run a deploy from the Actions tab ("Deploy" → Run workflow).

Production secrets live only in GitHub (environment `production`, usable only from `main`) and on the server. Never add real keys to this repo. `Dockerfile` builds two images (`app` and `worker`), and `docker-compose.yml` runs them with Postgres.
