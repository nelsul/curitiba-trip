# Android app

A native **Kotlin + Jetpack Compose** app for the trip, the Android twin of `ios/`, following the same design.

👉 **The plan is in [PLAN.md](PLAN.md)** (approach, installing without the Play Store, design parity, steps). The API it uses is documented in [`web/API.md`](../web/API.md).

## Status

| Done | Next |
|---|---|
| Project, design system (generated tokens and icons, fonts, buttons, cards, chips, top bar, dock), login (passport, "Quem é você?", email code), Diário (paged feed, carousels, likes, liked-by), photo/video and check-in pages (zoom, video, comments, captions, save the original to the gallery, delete), Roteiro (days, Uber, maps), Mais (profile photo with the circle framer, signed-in devices, sign out), Diário filters, Enviar (originals with their location, multipart upload with WorkManager that keeps going in the background and resumes, flight animation) | Mapa, background location, notifications |

Screens not built yet show "Abrir no site".

## Build and run

Needs Android Studio (it brings the JDK and SDK).

```bash
cd android
cp local.properties.example local.properties   # once; set sdk.dir
./gradlew :app:assembleDebug                    # or press Run in Android Studio
```

- **Emulator against your local web server** (no real emails): run the web app locally (`web/README.md`), then `adb reverse tcp:5174 tcp:5174` and set `apiBaseUrl=http://127.0.0.1:5174` in `local.properties`. Login codes show in the `npm run dev` terminal. `adb shell am start -n com.nelsul.curitibatrip.debug/com.nelsul.curitibatrip.MainActivity -e debugToken <token>` skips the login in debug builds.
- The debug app is `com.nelsul.curitibatrip.debug` ("Viagem"), so it can sit next to the real one.

## Design parity

- Colors, radii and depths come from `design/tokens.json` → `ui/theme/Tokens.kt` (`node design/build-tokens.mjs`; CI fails if stale).
- Icons come from the web's `Icon.svelte` → `res/drawable/ic_*.xml` (`node design/build-icons.mjs`).
- Fonts: Fredoka and Nunito (SIL Open Font License, see `app/licenses`).

## Secrets

Never commit `local.properties`, `keystore.properties` or any `.jks`/`.keystore` file; the root `.gitignore` excludes them.
