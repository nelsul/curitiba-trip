# Android app

The native **Kotlin + Jetpack Compose** app for the trip (Android 8+). It's the Android twin of [`ios/`](../ios): same design, same features, same API ([`web/API.md`](../web/API.md)).

The plan and the Android-specific decisions are in [PLAN.md](PLAN.md).

## Status

**Done**, matching the iPhone app:

- **Login:** passport card, "Quem é você?", 6-digit email code. The token is encrypted with an Android Keystore key.
- **Diário:** paged feed with day/person filters, carousels, double-tap and heart likes, "Curtido por", check-in posts, pull to refresh.
- **Photo/video and check-in pages:**
  - pinch-zoom, video, likes, comments, caption/note editing, delete
  - "Salvar original na galeria" (a "Viagem" album)
  - "Corrigir" a photo's location: search a place by name or drag the map
- **Diário + Reels:** tapping a post opens every photo and video full screen, swiping up like Reels (only the video on screen plays, double tap likes, share in a frame, owner/admin delete). "Todas as fotos" shows them in a grid; pick up to 9 photos to make one image with a frame (Polaroid, Passaporte, Noite, Casamento; post or story) and share it.
- **Cotinha:** split what someone paid (your Pix key is remembered); "Por pessoa" adds up what you owe each person, with "Paguei tudo" to settle them at once; their Pix key to copy, "Já paguei", the payer's "Cobrar quem falta" (a notification), a badge with what you owe.
- **Retrospectiva:** wedding countdown on the Diário; afterwards the admin's picks as stories.
- **Noivos:** a one-time special effect when the bride or groom liked your post.
- **Notificações** (the bell left of "Enviar", with an unread count) and **"Enviar só no Wi‑Fi"** in Enviar: off Wi‑Fi a ~720 px preview goes to the diary at once and the original waits for Wi‑Fi (also with the app closed); "Enviar agora" sends one anyway.
- **@menções** in comments, **previsão do tempo** hora a hora in the Roteiro, a **page per place**, and **Tirar foto / Gravar vídeo** in Enviar.
- **Enviar** (the yellow button at the top right): originals with their own location and time, sent in the background with WorkManager (resumes after network loss or the app closing), with the flight animation.
- **Mapa:**
  - MapLibre with the island style: polaroids, pins, people, filters
  - "Ir para onde estou": flies to you and shows the blue dot
  - check-in with a map picture
  - "Compartilhar local" while the app is open
- **Roteiro:** days, boarding-pass stops, "Pedir Uber", Google Maps.
- **Mais:**
  - profile photo (system photo picker + circle framer), signed-in devices, sign out
  - the "Avisos e localização" switches
- **In the background:**
  - your position on the map with the app closed (off by default; restarted after reboots)
  - group activity notifications
  - itinerary reminders 30 min before each stop
  - "Chegou em …? Fazer check-in" near itinerary stops

Not built yet: auto-import, widgets, an offline queue. Managing people stays on the website (`/admin`).

## How it's organized

```
app/src/main/java/com/nelsul/curitibatrip/
  MainActivity, TripApp, AppState   start-up, who's signed in, notification taps
  data/          Api (OkHttp + kotlinx.serialization), TokenStore (Keystore), models, TripTime, Gallery, Location, LocationSharing
  ui/            theme (Tokens.kt generated, fonts, motion) and components (buttons, cards, chips, dock, forms, flight animation)
  feature/       login, feed (+ grid, frames, couple effect), galeria (Reels), cotinha, retro, detail (pages + comments), enviar, mapa (map, markers, check-in, picker with place search), roteiro, more, shell (tabs)
  upload/        Uploads (job store), UploadWorker (R2 multipart), MediaReader (original + GPS from the gallery)
  background/    Notifier (activity, reminders, arrivals), BackgroundLocation (+ receivers)
```

How the native parts work:
- **Photo location:**
  - The system photo picker strips GPS.
  - With gallery access plus `ACCESS_MEDIA_LOCATION`, the app reads and uploads the untouched MediaStore original instead.
  - Without access it still works, just without the photo's location.
- **Uploads:**
  - Each file is a WorkManager job that sends 16 MB parts straight from the gallery file to R2.
  - Progress is saved after every part. Big files run as a foreground job with a progress notification.
- **Map pictures:** taken from the map on screen, centered on the check-in. MapLibre's off-screen snapshotter depends on the GPU driver.
- **Background location:**
  - Batched fused updates arrive at a receiver even with the app closed. They're queued and sent to `/api/locations/batch`.
  - Geofences cover the next itinerary stops.
  - This needs "Permitir o tempo todo", which Android 11+ grants on the app's settings page.
- **Notifications:** local only.
  - WorkManager checks `/api/activity` every ~15 min.
  - Itinerary reminders are delayed jobs.
  - Tapping a notification opens the post or the map's check-in.

## Build and run

Needs Android Studio (it brings the JDK and SDK).

```bash
cd android
cp local.properties.example local.properties   # once; set sdk.dir
./gradlew :app:assembleDebug                    # or press Run in Android Studio
```

The debug app is `com.nelsul.curitibatrip.debug`, so it can sit next to the real one.

### Against your local web server (no real emails)

1. Run the web app locally on a fixed port (`web/README.md`), e.g. 5174.
2. Run `adb reverse tcp:5174 tcp:5174`, and set `apiBaseUrl=http://127.0.0.1:5174` in `local.properties`. In this setup the emulator didn't reach the Mac at `10.0.2.2`.
3. Sign in as a local test person. The login code shows in the server's terminal.
4. Debug builds can skip the login:
   ```bash
   adb shell am start -n com.nelsul.curitibatrip.debug/com.nelsul.curitibatrip.MainActivity -e debugToken <token>
   ```

### Emulator tips

- **Test media:** `adb push` files to `/sdcard/Pictures`, then trigger a media scan (`am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Pictures/<file>`).
- **Position:** set it with `adb emu geo fix <lng> <lat>`.
- **Permissions:** grant them with `adb shell pm grant com.nelsul.curitibatrip.debug android.permission.<NAME>` to skip the dialogs.
- **Installing over a running app:** force-stop it first. Otherwise Android may get stuck on its "Updating…" screen.
- **Slow emulator:** the emulator is slow when the Mac is busy, so taps during start-up get lost. Wait for the screen first.

## Release APK (for friends' phones)

```bash
cd android
./gradlew :app:assembleRelease    # → app/build/outputs/apk/release/app-release.apk (arm64 + armv7, ~25 MB)
```

- **Signing:** it's signed with `keystore/release.jks` and `keystore.properties`, which exist only on Nelson's Mac and are git-ignored. **Keep a backup of both.** Every update must be signed with the same key, or phones refuse to install it over the old version.
- **For each new APK:**
  - Raise `versionCode` (and `versionName`) in `app/build.gradle.kts`.
  - To force everyone to update, also raise `MIN_APP_VERSION` in `web/src/lib/server/me.ts`.
- **Installing:** send the APK (WhatsApp, Drive…), open it on the phone, and allow "Instalar apps desconhecidos" once. Updates install over the old version and keep the data. Unlike free iPhone signing, it doesn't expire.
- **Server:** release builds always talk to `https://viagem.nelsul.com`.

## Design parity

- Colors, radii and depths come from `design/tokens.json` → `ui/theme/Tokens.kt` (`node design/build-tokens.mjs`; CI fails if stale).
- Icons come from the web's `Icon.svelte` → `res/drawable/ic_*.xml` (`node design/build-icons.mjs`).
- The launcher icon is an adaptive version of `design/app-icon.svg`.
- Fonts: Fredoka and Nunito (SIL Open Font License, see `app/licenses`).

## Secrets

Never commit `local.properties`, `keystore.properties` or any `.jks`/`.keystore`/`.apk` file. The root `.gitignore` excludes them.

- **Testing "só no Wi‑Fi" on the emulator:** `adb shell setprop debug.curitiba.nowifi 1` (debug builds) acts as if off Wi‑Fi; set it back to `0` afterwards.
