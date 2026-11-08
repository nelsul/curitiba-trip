# Android app plan

A native **Kotlin + Jetpack Compose** app for the trip, the Android twin of the iOS app (`ios/`). Same API (`web/API.md`), same look as the web and iOS apps, same features.

> Status: **built** (2026-11-08). How to build, test and release it is in [README.md](README.md).

## 1. Approach

| | Choice | Why |
|---|---|---|
| UI | Jetpack Compose, one activity | Same declarative model as SwiftUI, so screens port almost line by line |
| Language | Kotlin 2.4 | |
| Min / target | Android 8.0 (API 26) / API 37 | Covers practically every phone in the group |
| Networking | OkHttp + kotlinx.serialization, one `Api` object | Mirrors the iOS `API` (Bearer token, Portuguese error messages from the server) |
| Images | Coil 3 | Caches photos like NukeUI on iOS |
| Token | Android Keystore (AES) + SharedPreferences | The equivalent of the iOS Keychain |
| Map | MapLibre Android, the same island night style | Same as web and iOS |
| Uploads | WorkManager (long-running, with a progress notification) | Keeps sending with the app closed, like the iOS background `URLSession` |
| Location | Fused location (Google Play services) | Battery-friendly background updates, geofences for arrivals |
| Notifications | Local notifications from `/api/activity` (WorkManager, every ~15 min) | No push server, same as iOS |

## 2. Installing on phones (no Play Store)

Android installs apps from a file, with no fee or developer account:

1. Build a signed release APK on Nelson's Mac (`./gradlew assembleRelease`).
2. Send the `.apk` to each friend (WhatsApp, Drive, or a link).
3. On the phone: open the file and allow "Instalar apps desconhecidos" for that app once.

Updates are the same file with a higher version, installed over the old one (data is kept). Unlike free iOS signing, it **doesn't expire**.

The signing key (`android/keystore/release.jks` + `android/keystore.properties`) lives only on Nelson's Mac and is git-ignored. **Back it up**: updates must be signed with the same key.

## 3. Design parity

- Colors, radii and depths are generated from `design/tokens.json` into `ui/theme/Tokens.kt` by `design/build-tokens.mjs` (CI checks it).
- Icons are generated from the web's `Icon.svelte` into vector drawables by `design/build-icons.mjs`.
- Fredoka and Nunito, the same font files as iOS (OFL).
- Same components: dotted background, top bar, wooden day signs, chunky buttons, cards, chips, the floating dock with the raised yellow "Enviar" coin, polaroids, the passport login.

## 4. Steps

| Step | What | PR |
|---|---|---|
| 1 | Project, design system, login, Diário (feed, carousels, likes) | #11 ✔ |
| 2 | Photo/check-in pages, comments, Roteiro, Mais (profile photo, devices) | #13 ✔ |
| 3 | Diário filters; Enviar: gallery picker with location, background upload | #14 ✔ |
| 4 | Mapa: MapLibre, markers, trails, check-in with map picture, live sharing | #15 ✔ |
| 5 | Background location, notifications, itinerary reminders, arrival alerts | #16 ✔ |

Each was tested in the Android emulator against the local web server before merging. The emulator reached it through `adb reverse`; `10.0.2.2` didn't connect in this setup.

## 5. Android specifics

- **Photo location:** since Android 10, apps only see a photo's GPS with the `ACCESS_MEDIA_LOCATION` permission and `MediaStore.setRequireOriginal`. Without it the location is stripped.
- **Full quality:** upload the original file from `MediaStore`, never a re-encoded copy.
- **Background location** needs "Permitir o tempo todo", asked separately after "Durante o uso" (Android 11+ sends the person to Settings).
- **Notifications** need the `POST_NOTIFICATIONS` permission (Android 13+).
- **Map pictures for check-ins** are taken from the map on screen (`MapLibreMap.snapshot`), not with the off-screen `MapSnapshotter`, which depends on the GPU driver and never finished on the emulator.
- **Release builds** ship only arm64-v8a and armeabi-v7a native code (MapLibre), which brings the APK down from ~67 MB to ~25 MB.
