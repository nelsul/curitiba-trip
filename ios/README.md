# iOS app

The native **SwiftUI** app for the trip (iOS 17+). It's separate from the website, but it follows the same design and uses the same API ([`web/API.md`](../web/API.md)).

The original plan and decisions are in [PLAN.md](PLAN.md): install without the App Store, design parity, backend changes and native features.

## Status

The plan's MVP is **done**:

- **Login:** passport card, "Quem é você?", 6-digit email code.
- **Diário:** paged feed with day/person filters, carousels, double-tap and heart likes, "Curtido por", check-in posts.
- **Photo/video and check-in pages:**
  - zoom, video, likes, comments, caption/note editing, delete
  - "Salvar original nas Fotos"
  - "Corrigir" a photo's location: search a place by name or drag the map
- **Diário + Reels:** tapping a post opens every photo and video full screen, swiping up like Reels (only the video on screen plays, double tap likes, share in a frame, owner/admin delete). "Todas as fotos" shows them in a grid; pick up to 9 photos to make one image with a frame (Polaroid, Passaporte, Noite, Casamento; post or story) and share it.
- **Cotinha:** split what someone paid (your Pix key is remembered); "Por pessoa" adds up what you owe each person, with "Paguei tudo" to settle them at once; their Pix key to copy, "Já paguei", the payer's "Cobrar quem falta" (a notification), a badge with what you owe.
- **Retrospectiva:** wedding countdown on the Diário; afterwards the admin's picks as stories.
- **Noivos:** a one-time special effect when the bride or groom liked your post.
- **@menções** in comments, **previsão do tempo** hora a hora in the Roteiro, a **page per place**, and **Tirar foto / Gravar vídeo** in Enviar.
- **Enviar** (the yellow button at the top right): originals from the photo library with their own location and time, sent in the background (keeps going with the app closed), with the flight animation.
- **Mapa:**
  - MapLibre with the island style: polaroids, pins, people, filters
  - "Ir para onde estou": flies to you and shows the blue dot
  - check-in with a map picture
  - "Compartilhar local" while the app is open
- **Roteiro:** days, boarding-pass stops, "Pedir Uber", Google Maps.
- **Mais:**
  - profile photo with the circle framer, signed-in devices, sign out
  - the "Avisos e localização" switches
- **In the background:**
  - your position on the map with the app closed (off by default)
  - group activity notifications
  - itinerary reminders 30 min before each stop
  - "Chegou em …? Fazer check-in" near itinerary stops

Not built yet (PLAN.md §7): auto-import of the day's photos, widgets, Live Activity, the share extension, an offline queue. Managing people stays on the website (`/admin`).

## How it's organized

```
CuritibaTrip/
  App/            entry point, AppState (who's signed in), AppDelegate (background upload wake-ups)
  DesignSystem/   Theme.swift (generated tokens), fonts, icons, buttons, cards, chips, dock, flight animation
  Features/       Login, Feed (+ grid, frames, couple effect), Reels, Cotinha, Retro, Detail (pages + comments), Enviar, Mapa (map, markers, check-in, picker with place search), Roteiro, More, Shell (tabs + top bar)
  Services/       API client, Keychain token, dates (Curitiba time), Uploader, LocationSharing, Notifier
  Models/         Codable types matching web/API.md
```

How the native parts work:
- **Uploads** (`Services/Uploader.swift`):
  - The original is copied out of PhotoKit and cut into 16 MB part files.
  - The parts go to R2 with a background `URLSession`, so iOS keeps sending them while the app is suspended or closed.
  - Progress is saved to disk and resumed on launch, and `clientAssetId` stops duplicates.
- **Location** (`Services/LocationSharing.swift`):
  - With the app open, live updates (30 m / 3 min throttle) go to `/api/locations`.
  - With the app closed, significant-change and visit updates are queued with their real times and sent to `/api/locations/batch`. This needs "Sempre".
  - Arrival areas (150 m) cover the next itinerary stops.
- **Notifications** (`Services/Notifier.swift`): local only, with no push server.
  - A background refresh calls `/api/activity`; background location wake-ups check it too.
  - Itinerary reminders are scheduled from `/api/itinerary`.
  - Tapping a notification opens the post, or the map's check-in.

## Build and run

```bash
brew install xcodegen          # once
cd ios
cp Config/Local.xcconfig.example Config/Local.xcconfig   # once; add your Apple ID team for real devices
xcodegen                       # generates CuritibaTrip.xcodeproj (git-ignored; re-run after adding files)
open CuritibaTrip.xcodeproj
```

- **Simulator:** pick an iPhone and press Run. By default the app talks to `https://viagem.nelsul.com`.
- **Against your local web server** (no real emails):
  1. Run the web app locally (`web/README.md`).
  2. Set `API_BASE_URL = http:/$()/127.0.0.1:5173` (or your port) in `Config/Local.xcconfig`.
  3. Sign in as a local test person. The login code shows in the server's terminal.
  4. Debug builds can skip the login: `SIMCTL_CHILD_DEBUG_TOKEN=<token> xcrun simctl launch booted com.nelsul.curitibatrip`.
- **Command-line build for the simulator** (ad-hoc signing, so the Keychain works):
  ```bash
  xcodebuild -project CuritibaTrip.xcodeproj -scheme CuritibaTrip -destination 'platform=iOS Simulator,name=iPhone 17' \
    CODE_SIGN_STYLE=Manual 'CODE_SIGN_IDENTITY=-' DEVELOPMENT_TEAM= build
  ```

### Simulator tips

- Add test photos and videos with `xcrun simctl addmedia booted <files>`, and set a position with `xcrun simctl location booted set <lat>,<lng>`.
- Toggles ignore very short taps from automation; use a slightly longer press.
- The simulator doesn't open the app from a tapped notification, and doesn't fire arrival areas after a location jump. Test those on a real iPhone.

## Installing on friends' iPhones

There's no App Store and no paid account: each iPhone is connected to Nelson's Mac and the app is installed with his free Apple ID (PLAN.md §3).

1. Set `DEVELOPMENT_TEAM` in `Config/Local.xcconfig`.
2. Connect the iPhone, turn on Developer Mode, choose it in Xcode, and press Run.
3. On the iPhone, trust the developer in Settings › General › VPN & Device Management.

Free signing expires after **7 days**. Re-install before then (planned around 11/10 and 11/15). App data stays.

To force everyone onto a new version, raise `MARKETING_VERSION` in `project.yml` and `MIN_APP_VERSION` in `web/src/lib/server/me.ts`. Older apps then show "Nova versão".

## Design parity

- Colors, radii and fonts come from `design/tokens.json`. After changing it, run `node design/build-tokens.mjs`. It regenerates `DesignSystem/Theme.swift`, the web's `tokens.css` and Android's `Tokens.kt`, and CI fails if they're out of date.
- Icons come from the web's `Icon.svelte`. Run `node design/build-icons.mjs` after changing them.
- Fonts: Fredoka and Nunito static weights in `DesignSystem/Fonts` (SIL Open Font License; the license files are next to them).
- The app icon is drawn in `design/app-icon.svg`. The web favicon and the Android icon use the same design.

## Secrets

Never commit signing certificates, provisioning profiles, `Config/Local.xcconfig` or anything with keys. The root `.gitignore` already excludes them.
