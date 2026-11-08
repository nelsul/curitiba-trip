# AGENTS.md

Guide for AI coding agents working in this repo. Humans: start with [README.md](README.md) and [CONTRIBUTING.md](CONTRIBUTING.md); this file sums up what an agent needs and links to the details.

## The project

A private trip diary for a group of friends traveling to Curitiba (11–18/11/2026, wedding on 14/11). People sign in with an email code, post full-quality photos and videos with their location, check in on a map, like and comment. Live at https://viagem.nelsul.com. The owner and admin is Nelson.

One monorepo, three clients sharing one API and one look:

| Folder | What | Stack |
|---|---|---|
| `web/` | Website, JSON API (`src/routes/api`), media worker (`worker/`) | SvelteKit 2, Svelte 5 (runes), TypeScript, PostgreSQL + Drizzle, pg-boss, Cloudflare R2, MapLibre GL |
| `ios/` | Native iPhone app (iOS 17+) | SwiftUI, XcodeGen (`project.yml`), MapLibre Native, NukeUI |
| `android/` | Native Android app (Android 8+, target 37) | Kotlin, Jetpack Compose, OkHttp + kotlinx.serialization, Coil 3, WorkManager, MapLibre Android |
| `design/` | Single source of the look | `tokens.json`, `build-tokens.mjs`, `build-icons.mjs`, `app-icon.svg` |

The iOS and Android apps are twins: same screens (Login, Diário, Mapa, Galeria, Roteiro, Mais, and Enviar from the top bar), same behavior, same API. A feature added to one usually belongs in the other, and often on the website too. The feature table in README.md shows what exists where.

## Where to read more

| Topic | File |
|---|---|
| Web architecture, local dev, DB migrations, production deploy | [web/README.md](web/README.md) |
| Every API endpoint (the contract with the apps) | [web/API.md](web/API.md) |
| iOS: code layout, uploads/location/notifications, build, simulator tips | [ios/README.md](ios/README.md), [ios/PLAN.md](ios/PLAN.md) |
| Android: code layout, native parts, build, emulator tips, release APK | [android/README.md](android/README.md), [android/PLAN.md](android/PLAN.md) |
| Workflow and UI guidelines | [CONTRIBUTING.md](CONTRIBUTING.md) |

Read the relevant README before changing a part you haven't touched yet.

## Rules

### Secrets and privacy (most important)

- **Never commit or print secrets**: `.env`, R2 keys, SMTP credentials, the auth secret, server addresses, SSH keys, signing keys. The repo is **public**.
- Never put real people's email addresses in code, tests, commits, issues or PRs. Test people use `@example.test` addresses.
- Git-ignored and must stay that way: `web/.env`, `ios/Config/Local.xcconfig`, `android/local.properties`, `android/keystore.properties`, `android/keystore/`, any `.jks`/`.keystore`/`.apk`/`.ipa`.
- Before every push, check the diff (and new files) for anything secret-looking. `web/.env.example` holds only placeholders and public defaults.
- Production secrets live only in GitHub (environment `production`, usable from `main` only) and on the server.

### Workflow

- `main` is protected: always work on a branch and open a PR. Never push to `main`.
- **Merging a PR that touches `web/**` or `.github/workflows/**` deploys to production automatically** (`.github/workflows/deploy.yml`). Treat a merge as a deploy.
- CI (`.github/workflows/ci.yml`): `check` (required: design tokens up to date, `npm run check`, `npm run build`) and `android` (`./gradlew :app:assembleDebug`). iOS isn't built in CI, so build it locally when you change `ios/`.
- Merge with squash. Commit messages and PR descriptions are in English.

### Test locally first

- Run changes locally before opening a PR: the web app against the local Docker Postgres (`npm run dev:db`), the apps against the local web server (see each app's README for the exact setup).
- **Never send real emails while testing.** In dev the login code is printed in the server's terminal; sign in as local test people (`npm run user:add -- "Ana" ana@example.test`), or use `/dev-login` on the website. Debug builds of the apps accept a token at launch to skip the login (see the app READMEs).
- **Never run migrations or test writes against production** from a local machine. Production applies migrations by itself on start.
- Clean up any test data you create in a shared R2 bucket or database.

### Language and look

- **Everything people see is in Portuguese (pt-BR)**: labels, errors (including API error `message`s), notifications, `aria-label`s. Code, comments, commits and docs are in English.
- **Dark only**, the cozy island/travel theme. Use the design tokens (`var(--sea)` on the web, `Color.sea` in Swift, `Palette.sea` in Kotlin) and the shared icons. Don't add new colors or emoji icons in the UI.
- Mobile first: check at ~375 px wide; nothing should scroll sideways. Buttons at least 44 px.

### Generated files (don't edit by hand)

- `web/src/tokens.css`, `ios/CuritibaTrip/DesignSystem/Theme.swift`, `android/app/src/main/java/com/nelsul/curitibatrip/ui/theme/Tokens.kt` come from `design/tokens.json`. Change the JSON, then run `node design/build-tokens.mjs` (CI runs it with `--check`).
- App icons (iOS asset catalog, Android `res/drawable/ic_*.xml`) come from `web/src/lib/components/Icon.svelte` via `node design/build-icons.mjs`.
- `ios/CuritibaTrip.xcodeproj` is generated by `xcodegen` (git-ignored). Re-run `xcodegen` in `ios/` after adding or removing files.
- Drizzle migrations in `web/drizzle/` come from `npm run db:generate -- --name <short_name>` after editing `web/src/lib/server/db/schema.ts`. Commit the SQL and `drizzle/meta`.

### API changes

- The apps on people's phones run older versions until reinstalled. **Add fields; don't rename or remove them**, and keep old request shapes working.
- Update `web/API.md` with every endpoint change, and the Swift (`ios/CuritibaTrip/Models/`) and Kotlin (`android/.../data/Models.kt`) models when the apps use it.
- To force old apps to update, raise `MIN_APP_VERSION` in `web/src/lib/server/me.ts` along with the apps' versions (`MARKETING_VERSION` in `ios/project.yml`, `versionCode`/`versionName` in `android/app/build.gradle.kts`).
- Shared logic the apps depend on lives on the server: feed grouping (`web/src/lib/feed-group.ts`, used by `/api/feed`), the map style (`/api/map-style.json` from `src/lib/map-style.ts`), the itinerary (`src/lib/itinerary.ts`; keep stop times like `9h35` or `14h`, the apps parse them for reminders).
- Times are shown in Curitiba time (`America/Sao_Paulo`); days are `YYYY-MM-DD` in that zone.

## Commands

```bash
# Web (in web/)
cp .env.example .env && npm install     # once
npm run dev:db && npm run db:migrate    # local Postgres in Docker
npm run dev                             # http://localhost:5173 (/dev-login to sign in)
npm run worker                          # media processing (needs exiftool, vips, ffmpeg)
npm run check && npm run build          # what CI runs
node ../design/build-tokens.mjs --check

# Android (in android/)
./gradlew :app:assembleDebug            # what CI runs
./gradlew :app:assembleRelease          # signed APK; needs the release key, only on Nelson's Mac

# iOS (in ios/)
xcodegen
xcodebuild -project CuritibaTrip.xcodeproj -scheme CuritibaTrip \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGN_STYLE=Manual 'CODE_SIGN_IDENTITY=-' DEVELOPMENT_TEAM= build
```

To test an app against a local server, run the web app on a fixed port (`npx vite dev --port 5174 --strictPort --host 127.0.0.1`), then:
- Android emulator: `adb reverse tcp:5174 tcp:5174` and `apiBaseUrl=http://127.0.0.1:5174` in `android/local.properties` (`10.0.2.2` didn't connect in this setup).
- iOS simulator: `API_BASE_URL` in `ios/Config/Local.xcconfig`.

There are no automated test suites; verification is the type check, the builds, and running the change (browser at phone size, simulator, emulator).

## Known pitfalls

- **Android emulator:** force-stop the app before reinstalling, or it can get stuck on "Updating…" (reboot the emulator if it does). MapLibre's off-screen `MapSnapshotter` never finishes on the emulator's GPU, so check-in pictures are taken from the on-screen map. Work that must outlive a screen (e.g. the snapshot upload) needs its own coroutine scope.
- **Android location:** the system photo picker strips GPS; the app reads the MediaStore original with `ACCESS_MEDIA_LOCATION` + `setRequireOriginal`. `getCurrentLocation` can hang, so it has a timeout and a last-known fallback.
- **iOS simulator:** switches ignore very short automated taps; tapped notifications don't open the app, and arrival areas don't fire after a location jump (test those on a real phone). Code touching `CLLocationManager.monitoredRegions` must tolerate concurrent refreshes (see `LocationSharing.updateArrivalRegions`).
- **iOS concurrency:** Photos/PhotoKit callbacks run off the main actor; keep such helpers `nonisolated` to avoid crashes.
- **No location trails:** they were removed because background positions weren't reliable. `/api/map` still returns `pings` (always `[]`) so installed apps keep decoding it; don't bring trails back without asking.
- **Background work is local only:** there is no push server. Notifications come from polling `/api/activity`; background location is batched to `/api/locations/batch`.
- **Installs:** iOS apps are signed with a free Apple ID and expire after 7 days (reinstalled from Nelson's Mac). Android ships as a signed APK; every update must use the same release key.
