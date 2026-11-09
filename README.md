# Curitiba Trip ✈️🏝️

Our shared trip diary for Curitiba (11–18/11/2026, wedding on 14/11). Everyone signs in with an email code, posts full-quality photos and videos with their location, checks in on the map, likes and comments. Everything merges into one diary and one map.

Live at **https://viagem.nelsul.com** (only people on the list can sign in). There are also native apps for iPhone and Android with the same look and features.

## What's in here

| Folder | What | Stack |
|---|---|---|
| [`web/`](web) | The website (mobile-first), the JSON API the apps use, and the media worker | SvelteKit 2 · Svelte 5 · TypeScript · PostgreSQL + Drizzle · Cloudflare R2 · MapLibre · pg-boss + ffmpeg/libvips/exiftool |
| [`ios/`](ios) | Native iPhone app, installed from Nelson's Mac (no App Store) | SwiftUI · iOS 17+ · XcodeGen · MapLibre Native · NukeUI |
| [`android/`](android) | Native Android app, shared as a signed APK (no Play Store) | Kotlin · Jetpack Compose · Android 8+ · MapLibre Android · WorkManager · Coil |
| [`design/`](design) | The single source of the look: design tokens, icon export, app icon | Node scripts that generate the web CSS, `Theme.swift` and `Tokens.kt` |

The interface is 100% in Portuguese (pt-BR). Code, comments and commit messages are in English.

## Features (all three)

| | Website | iPhone | Android |
|---|---|---|---|
| Login: pick your name, 6-digit code by email | ✔ | ✔ | ✔ |
| **Diário:** feed newest first, carousels, likes, comments, day/person filters | ✔ | ✔ | ✔ |
| **Galeria:** every photo and video full screen, swipe up like Reels; only the video on screen plays | ✔ | ✔ | ✔ |
| **Enviar** (yellow button, top right): originals in full quality with their own location and time | ✔ | ✔ (keeps sending with the app closed) | ✔ (keeps sending with the app closed) |
| **Mapa:** polaroids, check-ins, live sharing, "go to where I am", check-in with a map picture | ✔ | ✔ | ✔ |
| Mark or fix a photo's location: search a place by name, or pick it on the map | ✔ | ✔ | ✔ |
| **Roteiro:** places to go and eat (photos, hours, prices, Uber), day-by-day itinerary with a route map, editable by everyone, "Fomos!" ticks shared by the group | ✔ | ✔ | ✔ |
| **Mais:** profile photo with a circle framer | ✔ | ✔ | ✔ |
| Signed-in devices (sign one out) | — | ✔ | ✔ |
| Save the original photo/video to the phone | download | Fotos | galeria |
| Your position on the map with the app closed (off by default) | — | ✔ | ✔ |
| Notifications: group activity, itinerary reminders, "Chegou? Fazer check-in" | — | ✔ | ✔ |
| Admin: manage people | ✔ (`/admin`) | opens the site | opens the site |

## Quick start (web)

You need Node 22.18+ and Docker.

```bash
cd web
cp .env.example .env      # local-only values, never commit .env
npm install
npm run dev:db            # local Postgres in Docker
npm run db:migrate
npm run dev               # http://localhost:5173
```

Then open **http://localhost:5173/dev-login**. It signs you in as a throwaway test user, works only in dev, and returns 404 in production. More in [`web/README.md`](web/README.md).

The apps can run against this local server too: see [`ios/README.md`](ios/README.md) and [`android/README.md`](android/README.md).

## How changes ship

- `main` is protected: every change goes through a pull request.
- CI (`.github/workflows/ci.yml`) runs on every PR:
  - `check` (required): design tokens are up to date, then the web type check and build.
  - `android`: builds the Android debug APK.
- **Merging into `main` deploys the website and API automatically** (`deploy.yml`).
- The apps aren't deployed. Nelson builds and installs them:
  - iPhone: from his Mac, with Xcode.
  - Android: a new signed APK, sent to the group.

## Docs

| | |
|---|---|
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Workflow, guidelines, secrets |
| [`web/README.md`](web/README.md) | How the website and worker fit together, local development, database changes, production |
| [`web/API.md`](web/API.md) | Every API endpoint the apps use |
| [`ios/README.md`](ios/README.md) · [`ios/PLAN.md`](ios/PLAN.md) | iPhone app: build, test, install; the original plan |
| [`android/README.md`](android/README.md) · [`android/PLAN.md`](android/PLAN.md) | Android app: build, test, release APK; the plan |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). In short: branch, keep the cozy-island look, test on a phone-sized screen, open a PR. **Never commit secrets.**
