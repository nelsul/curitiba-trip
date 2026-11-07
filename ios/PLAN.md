# iOS app: plan

> Status: **planning** · Written on 2026-11-06 · The trip runs 11–18/11/2026, with the wedding on 11/14.

## 1. Goals

1. An iPhone app for the group that **looks and behaves exactly like the web app** (same cozy island and night design, same screens, in Portuguese).
2. Add what a website **can't** do: location in the background, uploads that finish with the app closed, the photo library with original quality and location, notifications, widgets, Live Activities and the share sheet.
3. **Not on the App Store.** Friends install it directly ("developer mode", see §3).
4. A useful first version **installed before the flights** (by Tuesday 11/10). Extras can come during or after the trip.

Out of scope: an Android app (only if someone in the group needs it; the chosen approach makes that cheap later), and App Store review or marketing.

## 2. Approach: native shell around the web UI

**Decision: Capacitor (native iOS shell) + Swift for the native features.**

| | A. Native shell (Capacitor) ✅ | B. Full SwiftUI |
|---|---|---|
| Same design as the web app | **Identical by construction:** the screens *are* the web UI | Rebuilt by hand, so ~15 screens and every animation; drifts over time |
| Native features | Yes, through plugins plus our own Swift code | Yes |
| Ready before 11/11 | Yes (core) | No |
| Later | Can move screen by screen to SwiftUI if wanted, using the same API (§5) | — |

How it works:

- The app opens `https://viagem.nelsul.com` in the shell's built-in browser view. Every web deploy (merge into `main`) updates the app instantly, with no reinstall.
- The web code checks whether it's running inside the app (`Capacitor.isNativePlatform()`). If so, it uses native features instead of browser ones. For example, "Compartilhar localização" starts background tracking, and "Enviar" opens the native photo picker that keeps location.
- Widgets, the Live Activity and the Share Extension are small Swift targets. They talk to the API directly using a token from the Keychain (§5.1).
- If the network is down when the app opens, a small bundled offline screen ("Sem conexão: tentando de novo…") replaces the website.

## 3. Distribution without the App Store

iOS only runs apps signed by an Apple account. Two ways to sign, each with real trade-offs:

| | Free Apple ID ("Personal Team") | Apple Developer Program (US$99/year), **Ad Hoc** |
|---|---|---|
| How friends install | Each iPhone is **plugged into Nelson's Mac**, and Xcode installs the app. **Developer Mode** must be on (Settings → Privacy & Security → Developer Mode). | A link: an install page on `viagem.nelsul.com/app` (over-the-air install), no cable. Each iPhone's ID must be registered first (up to 100 devices). |
| How long it works | **7 days**, then the app stops opening until it's reinstalled. Installed 11/10, it would expire on 11/17, before the trip ends. | 1 year |
| Push notifications | ❌ Not available to free accounts | ✅ |
| Wallet pass | ❌ | ✅ |
| Widgets, Share Extension | Probably ✅, but sharing data between app and extensions (App Groups / Keychain sharing) **must be checked in Xcode on day 1** | ✅ |
| Background location, background uploads, Live Activity (updated locally), Siri | ✅ | ✅ |
| Other limits | Max 3 sideloaded apps per iPhone; App ID limits per week | — |

**Recommendation:** the paid program. Push notifications and lasting the whole trip are the difference between a demo and something people rely on. With a free account, plan a re-install session around 11/16 and drop the ❌ features.

To collect device IDs for Ad Hoc: each friend opens a profile link or reads the ID in Finder. **Do this before 11/10.**

## 4. Design parity

The screens are the web UI, so parity is automatic there. For the native parts (widgets, Live Activity, Share Extension, offline screen, launch screen):

- **One source of design tokens:** move colors, rounding, shadows and fonts from `web/src/app.css` into `design/tokens.json`. A small script generates `web/src/tokens.css` and `ios/native/App/Theme.swift`, so the two can't drift.
- **Fonts:** bundle Fredoka and Nunito (open licenses) in the app.
- **Icons:** export the paths from `Icon.svelte` as SVG into the Xcode asset catalog (template images).
- **Map:** the shell shows the same MapLibre web map. Native extras (the Live Activity map, widget snapshots) use the same style JSON served by the API (§5).
- **Motion:** the native pieces copy the web's springs (the `--bounce` curve), the pin drop, the stamp and the plane, and use haptics on taps that "press". All of it respects Reduce Motion.
- **Dark only, Portuguese only,** just like the web.
- **Safe areas:** the web already uses `env(safe-area-inset-*)` and `viewport-fit=cover`. Check the notch, the Dynamic Island and the home indicator on a real device.

## 5. Backend changes (in `web/`, before the app)

These also help the web app, and they're what a future SwiftUI app would need.

### 5.1 Auth with tokens

- `GET /api/auth/people`: the "Quem é você?" list (id, name, color, photo).
- `POST /api/auth/code` `{ userId }` → `{ maskedEmail }`
- `POST /api/auth/verify` `{ userId, code, device }` → `{ token, user }`
- `POST /api/auth/token`: exchanges the current **cookie** session for a **device token**. It's how the shell, after the normal web login, hands a token to the native code and extensions.
- `POST /api/auth/logout` revokes this device's token.
- `hooks.server.ts` accepts `Authorization: Bearer <token>` as well as the cookie. Same `sessions` table (sha256 of the token), with a `kind` (`cookie` or `device`) and a `deviceName` so `/mais` can list and revoke devices.
- Tokens live in the iOS Keychain, in an access group shared with the extensions.

### 5.2 JSON endpoints (today the data only reaches pages rendered on the server)

| Endpoint | Notes |
|---|---|
| `GET /api/feed?before=<cursor>&limit=30` | **Paginated**, newest first. Today the feed loads everything; the web feed switches to this too. |
| `GET /api/map?day=YYYY-MM-DD` | Pins, check-ins, trails and latest positions. |
| `GET /api/media/:id`, `PATCH` (caption, location), `DELETE` | Replaces the form actions on `/m/[id]`. |
| `GET/POST /api/media/:id/comments`, `DELETE /api/comments/:id` | Same for check-ins. |
| `GET /api/people`, `GET /api/me` | |
| `GET /api/itinerary` | Moves `itinerary.ts` into data (it also gets it out of the public repo). |
| `GET /api/map-style.json` | The island and night style from `map-style.ts`, for native map snapshots. |

The existing `/api/uploads`, `/api/likes`, `/api/checkins` and `/api/users/:id/avatar` stay as they are.

### 5.3 Uploads from the photo library

- Add a `clientAssetId` (the iPhone's photo ID) with a unique index per person. Re-sending is a no-op, so retries and auto-import never create duplicates.
- Location and capture time come from the photo library entry (`PHAsset.location` / `creationDate`), sent as the upload's metadata (`locationSource: 'device-library'`). The worker still reads the file's own metadata and keeps whichever is better.

### 5.4 Background location

- `POST /api/locations/batch` `[{ lat, lng, accuracy, at }]`: the client's timestamps are accepted, limited to the last 48 hours with no future times. They're thinned on the server (≥30 m or ≥3 min apart) like today.

### 5.5 Push notifications (only with the paid account)

- `devices` table (`userId`, APNs token, environment, last seen) and `POST /api/devices`.
- The worker sends through Apple's push service with a `.p8` key stored as a **GitHub secret** in the `production` environment (never in the repo).
- Events: a new post by someone else (batched every ~10 min, "Bruna e Carlos postaram 7 fotos"), a comment on your post, likes on your post (batched), check-in reminders (§6), and a "next stop" heads-up from the itinerary.
- Settings in `/mais`: which notifications each person wants.

### 5.6 Housekeeping

- `X-App-Version` header and `minAppVersion` in `/api/me`, so old builds get a "please reinstall" screen.
- Rate limits on the auth endpoints (codes are already throttled per person).

## 6. Native features

Each feature lists its phase and whether it needs the paid account.

| # | Feature | What it does | Phase | Paid? |
|---|---|---|---|---|
| 1 | **Location in the background** | The map works with the app closed, using battery-friendly significant-change and visit tracking. Each person's daily trail draws itself. On/off in `/mais`, off by default, with clear wording. | 1 | — |
| 2 | **"Fotos de hoje" auto-import** | Each evening the app lists the day's photos taken in Curitiba and posts the ones you pick in one tap. Original quality, location from the photo library (no Safari stripping). | 1 | — |
| 3 | **Uploads that finish in your pocket** | A background upload session: the app can be closed mid-upload. Uses the existing chunked R2 upload. | 1 | — |
| 4 | **Share Extension** | Choose "Viagem" in the Photos share sheet to post with a caption. | 1 | (App Group: check) |
| 5 | **Push notifications** | §5.5 | 1 | ✅ |
| 6 | **Arrival check-ins** | Geofences around the itinerary stops. On arrival: "Chegou no Jardim Botânico! Fazer check-in?" (a local notification, so no push needed). | 1 | — |
| 7 | **Live Activity / Dynamic Island** | Today's next stop with a countdown and transport ("Ópera de Arame em 25 min · 🚍 Linha Turismo"). Wedding day: "Uber de volta 1h30". Updated by the app and timers. | 2 | — (push updates need ✅) |
| 8 | **Widgets** | Countdown to the wedding, today's next stop, the group's latest photo, "who's nearby". | 2 | (App Group: check) |
| 9 | **Câmera da viagem** | An in-app camera with a passport-stamp frame, posting straight to the diary, with haptic feedback. | 2 | — |
| 10 | **Offline mode** | Posts and check-ins queue without signal (Morretes, the Graciosa road). The itinerary and Curitiba map are kept offline. | 2 | — |
| 11 | **Siri / Shortcuts / Action button** | "Fazer check-in na viagem", "Próxima parada". | 2 | — |
| 12 | **Wallet pass "Passaporte da viagem"** | Each day's itinerary as a boarding pass that shows on the Lock Screen near each stop. | 3 | ✅ |
| 13 | **Retrospectiva** | A recap video of everyone's moments, made on the phone, after the trip. | 3 | — |

Phase 1 = before the flights. Phase 2 = during the trip, delivered as web deploys plus one app update. Phase 3 = after.

### Privacy

- Background location is **off by default**, can be stopped any time, and only goes to the group. Points older than the trip plus 30 days can be deleted (add a setting).
- Auto-import only **suggests**: nothing is posted without a tap.
- Notifications are per type, and each can be turned off.

## 7. Project layout

```
ios/
  PLAN.md                  ← this file
  README.md
  package.json             ← Capacitor CLI + plugins (versions pinned when added)
  capacitor.config.ts      ← appId, server.url = https://viagem.nelsul.com, ios.path = "native"
  offline/                 ← bundled offline screen (www for Capacitor)
  native/App/              ← Xcode project generated by Capacitor
    App/                   ← AppDelegate, Theme.swift (generated), custom plugins:
      Plugins/PhotoLibrary ← PHAsset originals + location, background URLSession upload
      Plugins/Geofences    ← itinerary stops → local notifications
      Plugins/LiveActivity ← ActivityKit bridge
      Plugins/Session      ← Keychain token shared with extensions
    ShareExtension/
    Widgets/               ← WidgetKit + Live Activity UI
design/
  tokens.json              ← single source of colors, radii, fonts (web + iOS)
```

Plugins to use, with exact versions pinned when added: the official Capacitor push notifications, local notifications, geolocation, haptics, status bar, app and preferences plugins, plus a community background-geolocation plugin, or our own Swift if it doesn't meet the battery needs.

Bundle ID: `com.nelsul.curitibatrip` (to confirm).

## 8. Timeline

| When | What |
|---|---|
| **Sat 11/07** | Backend PR 1: token auth (§5.1) and bearer support. Backend PR 2: JSON endpoints and feed paging (§5.2), with the web feed switched to paging. |
| **Sun 11/08** | Backend PR 3: `clientAssetId`, batched locations, devices and push (§5.3–5.5). Capacitor shell running on a device, plus the offline screen and design tokens. Collect device IDs (Ad Hoc). |
| **Mon 11/09** | Phase 1 native features: background location, the photo library picker and background upload, auto-import, the Share Extension and arrival check-ins. Test on 2+ real iPhones, including a weak network. |
| **Tue 11/10** | **Install session** with everyone (link or cable). Fallback for anyone who can't install: the website keeps working as it does today. |
| 11/11–18 | Phase 2 as time allows (most of it is web-side, so it deploys without reinstalling). |
| After | Phase 3; decide whether any screens should go fully SwiftUI. |

## 9. Testing

- **Backend:** the `check` CI runs on every PR. Add API tests for auth tokens, paging and upload deduplication (Vitest and a test database in CI).
- **Local:** the web app as today (`web/README.md`); the shell can point at `http://<mac-ip>:5173` for development (`capacitor.config.ts` per environment).
- **Devices:** at least 2 iPhones (one older), a Low Power Mode run, a run with the app closed for location and uploads, and an airplane-mode run for the offline queue.
- **Battery:** a half-day walk with background location on, before the trip.

## 10. Risks

| Risk | Mitigation |
|---|---|
| Free signing expires on day 7 | Pay for the program, or plan a re-install on ~11/16. |
| Not every friend has an iPhone | The website stays fully supported. Android through the same shell later if needed. |
| A 4-day deadline | Phase 1 is the must-have. Everything else ships as web deploys. |
| Background location draining batteries | Significant-change and visit tracking only, plus an easy off switch. |
| Duplicate uploads from retries or auto-import | `clientAssetId` unique per person. |
| Secrets in a public repo | The APNs key and device tokens only in GitHub `production` secrets and the database. Never in `ios/`. The `.gitignore` covers `*.p8`, `*.p12` and provisioning profiles. |

## 11. Decisions needed from Nelson

1. **Account:** the paid Apple Developer Program (Ad Hoc, push, 1 year) or a free Apple ID (cable install, 7 days, no push)?
2. **Approach A (Capacitor shell)**, as planned here, confirmed?
3. **Which iPhones:** whose devices, and does anyone use Android?
4. **Phase 1 scope:** features 1–6, as above?
