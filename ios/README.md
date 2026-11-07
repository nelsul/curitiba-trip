# iOS app

A native **SwiftUI** app for the trip (iOS 17+), separate from the web app but following its design exactly.

👉 **The full plan is in [PLAN.md](PLAN.md):** approach, installing without the App Store, design parity, backend changes, screens, native features, layout and timeline. The API it uses is documented in [`web/API.md`](../web/API.md).

## Status

| Done | Next |
|---|---|
| Project (XcodeGen), design system (tokens, fonts, icons, buttons, cards, chips, top bar, dock), login (passport, "Quem é você?", email code), Diário (paged feed, carousels, likes, liked-by), photo/video and check-in pages (zoom, comments, captions, save original, delete), Roteiro (days, Uber, maps), Mais (profile photo framer, signed-in devices, sign out), Enviar (originals from the photo library with location, background multipart upload that survives closing the app, flight animation), Mapa (MapLibre: polaroids, pins, people, trails, day/person filters, check-in with a map picture, live location sharing while the app is open, fixing a photo's location) | Background location, local notifications |

Screens not built yet show "Abrir no site".

## Build and run

```bash
brew install xcodegen          # once
cd ios
cp Config/Local.xcconfig.example Config/Local.xcconfig   # once; add your Apple ID team for real devices
xcodegen                       # generates CuritibaTrip.xcodeproj (git-ignored; re-run after adding files)
open CuritibaTrip.xcodeproj
```

- **Simulator:** pick an iPhone and press Run. By default the app talks to `https://viagem.nelsul.com`.
- **Against your local web server** (no real emails): run the web app locally (`web/README.md`, with `npm run dev:db`), then set `API_BASE_URL = http:/$()/127.0.0.1:5173` in `Config/Local.xcconfig`. Login codes show in the `npm run dev` terminal.
- **Real iPhones** (free Apple ID, Developer Mode): see PLAN.md §3. Set `DEVELOPMENT_TEAM` in `Config/Local.xcconfig`.

## Design parity

- Colors, radii and fonts come from `design/tokens.json`. After changing it, run `node design/build-tokens.mjs`; it regenerates `DesignSystem/Theme.swift` and the web's `tokens.css`, and CI fails if they're out of date.
- Icons come from the web's `Icon.svelte`. Run `node design/build-icons.mjs` after changing them.
- Fonts: Fredoka and Nunito static weights in `DesignSystem/Fonts` (SIL Open Font License; the license files are next to them).
- The app icon is drawn in `design/app-icon.svg`; the web favicon uses the same design.

## Secrets

Never commit signing certificates, provisioning profiles, `Config/Local.xcconfig` or anything with keys. The root `.gitignore` already excludes them.
