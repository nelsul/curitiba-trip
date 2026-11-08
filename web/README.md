# Web app

SvelteKit app (the website + the JSON API the iPhone and Android apps use) plus a background worker for photos and videos.

## How it fits together

```
Browser / iOS / Android ──► SvelteKit app (src/) ──► PostgreSQL (Drizzle, migrations in drizzle/)
   │  (cookie or Bearer)            │
   │                                └─► pg-boss queue ──► worker (worker/): exiftool, libvips, ffmpeg
   │                                                            │
   └── uploads go straight to Cloudflare R2 ◄───────────────────┘ (originals untouched; thumb/medium/display/video derived)
```

- **Login:** pick your name, get a 6-digit code by email. In dev the code is printed in the terminal instead of emailed. The website keeps a session cookie; the apps get a token and send it as `Authorization: Bearer …`. Both are rows in `sessions` (only a SHA-256 of the token is stored).
- **API:** everything under `src/routes/api` is documented in [`API.md`](API.md), including the endpoints only the apps use (`/api/activity` for notifications, `/api/locations/batch` for background location, `clientAssetId` to avoid duplicate uploads).
- **Uploads:** the browser uploads in chunks directly to R2 (presigned multipart). GPS and capture time come from the file: in the browser for photos, in the worker for videos.
- **Feed** (`src/routes/(app)/+page.svelte`): Instagram-style, newest first, with day and person filters. Photos from the same person on the same day within 30 min become a carousel (`src/lib/feed-group.ts`, shared with `GET /api/feed` so the apps group the same way). Likes and comments.
- **Map** (`src/routes/(app)/mapa`): MapLibre with OpenFreeMap tiles, recolored in `src/lib/map-style.ts` (the apps load the same style from `/api/map-style.json`). It shows located photos, check-ins, each person's trail and latest position. Each check-in gets a map picture, drawn in the browser (`src/lib/map-snapshot.ts`) or by the app, and uploaded to `/api/checkins/:id/snapshot`.
- **Roteiro:** the itinerary is static data in `src/lib/itinerary.ts`, also served to the apps by `/api/itinerary` (they use it for reminders and arrival alerts, so keep stop times like `9h35` or `14h`).
- **Theme:** dark only. Colors and sizes come from `src/tokens.css`, generated from `design/tokens.json` by `node ../design/build-tokens.mjs` (don't edit it by hand). The icons are in `src/lib/components/Icon.svelte` and are exported to the apps by `design/build-icons.mjs`.

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
- **Testing the apps against this server:** run it on a fixed port the apps point to, e.g. `npx vite dev --port 5174 --strictPort --host 127.0.0.1`, then follow `ios/README.md` or `android/README.md`. The apps need people to sign in as: add test people with `user:add` and `@example.test` addresses, so no real person gets an email.

## Checks

```bash
npm run check   # svelte-check + TypeScript
npm run build   # production build (app + worker bundle)
node ../design/build-tokens.mjs --check   # generated design tokens are up to date
```

## Database changes

1. Edit `src/lib/server/db/schema.ts`.
2. Run `npm run db:generate -- --name short_description` to create a SQL migration in `drizzle/`.
3. Run `npm run db:migrate` to apply it locally. Production applies migrations automatically when the app starts.

Commit the generated SQL and `drizzle/meta` files.

## Production

Merging into `main` deploys automatically (`.github/workflows/deploy.yml`):

1. CI runs again: the tokens check, `npm ci`, the type check, and the build.
2. A `.env` is written from the **production** environment secrets on GitHub.
3. `web/` is sent to the VPS over SSH and rebuilt with `docker compose up -d --build`. The deploy key on the server can only run that deploy.
4. A smoke test checks that the site responds.

You can also re-run a deploy from the Actions tab ("Deploy" → Run workflow).

Changes to the API reach phones that run older app versions too, so add fields instead of renaming or removing them. If old apps must be replaced, raise `MIN_APP_VERSION` in `src/lib/server/me.ts` (it applies to both apps' `versionName`/`CFBundleShortVersionString`), and older versions show "Nova versão".

Production secrets live only in GitHub (environment `production`, usable only from `main`) and on the server. Never add real keys to this repo. `Dockerfile` builds two images (`app` and `worker`), and `docker-compose.yml` runs them with Postgres.
