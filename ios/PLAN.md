# iOS app: plan

> Status: **planning, decisions made** · Updated 2026-11-06 · The trip runs 11–18/11/2026, with the wedding on 11/14.

**Decided by Nelson:**
- **Full SwiftUI** native app.
- **No paid Apple Developer Program.** The app is signed with Nelson's **free Apple ID** and installed by connecting each friend's iPhone to Nelson's Mac (§3).

## 1. Goals

1. A native iPhone app that **follows the web app's design exactly**: the same cozy island and night theme, components, motion and Portuguese text.
2. Do what a website can't: location in the background, uploads that finish with the app closed, the photo library with original quality and location, notifications, widgets, Live Activities and the share sheet.
3. Friends install it **from Nelson's Mac**, no App Store and no paid account (§3).
4. A first version on everyone's phone **before the flights** (install session Tue 11/10). The website stays the fallback.

Out of scope for now: Android (see §12) and the App Store.

## 2. Approach

A SwiftUI app, **iOS 17+**, talking to the same backend as the web (`https://viagem.nelsul.com`). There's no separate server: the web app's API gets the endpoints the app needs (§5), and the web uses them too.

| Area | Choice |
|---|---|
| UI | SwiftUI, `@Observable` state (Observation framework), `async/await` |
| Networking | `URLSession` + `Codable`, one `APIClient` |
| Auth storage | Keychain (shared access group for the extensions) |
| Images | `Nuke` (Swift Package): disk cache and prefetching for the feed. `AsyncImage` doesn't cache well enough. |
| Video | AVKit `VideoPlayer` |
| Map | **MapLibre Native** (Swift Package) with the **same night island style** as the web, served by the API |
| Photos | PhotoKit (`PHAsset`, original HEIC/HEVC + location) |
| Uploads | Background `URLSession`, one upload task per chunk, against the existing R2 multipart flow |
| Location | Core Location: significant-change + visits in the background; standard updates while the map is open |
| Notifications | **Local** notifications driven by background refresh and location wake-ups (free signing has no push, §5.5) |
| Project | **XcodeGen** (`project.yml` committed; the `.xcodeproj` is generated and git-ignored), so PRs don't fight over project files |

Third-party code is kept to two packages: MapLibre and Nuke. Exact versions are pinned when added.

## 3. Distribution: free signing from Nelson's Mac

Xcode signs the app with Nelson's **free Apple ID** ("Personal Team") and installs it directly on each iPhone.

### What each friend does (once, ~10 minutes, with Nelson)
1. **Update the iPhone** to at least **iOS 17**.
2. **Connect it to Nelson's Mac** with a cable, unlock it and tap **Trust This Computer**.
3. Nelson clicks **Run** in Xcode with that iPhone selected. Xcode registers the device and installs the app.
4. On the iPhone, turn on **Developer Mode** (Settings → Privacy & Security → Developer Mode); the phone restarts. The option appears after the first install attempt from Xcode.
5. Allow the developer: Settings → General → VPN & Device Management → Nelson's Apple ID → **Trust**.
6. Open "Viagem", sign in with the email code, and allow photos, location and notifications.

After the first cable session, Xcode can also install **over Wi-Fi** when the Mac and the iPhone are on the same network (Xcode → Devices → "Connect via network"). Updates during the trip then don't need a cable.

### Limits of free signing (to verify on day 1)

| Limit | Impact | What we do |
|---|---|---|
| **The app expires after 7 days** | Installed Tue 11/10, it stops opening around **Tue 11/17**, before the trip ends (11/18) | Install as late as possible on 11/10, and **re-install around 11/15–16** in Curitiba (over Wi-Fi if Nelson brings the Mac). If the Mac doesn't travel, the website covers the last days. |
| **No push notifications** (APNs needs the paid program) | No "Carlos comentou" alerts arriving from the server | Local notifications from background checks (§5.5): best effort, not instant |
| **No Wallet passes** | — | Wallet pass dropped |
| **App Groups / Keychain sharing for extensions** may not be available to free teams | Widgets and the Share Extension need to share the login with the app | Check in Xcode on day 1. If not available: widgets fetch public data without login, and the Share Extension is dropped. |
| **App ID limits** (a small number of new app IDs per week, and few sideloaded apps per device) | Each extension uses an app ID | Keep it to the app plus at most 2 extensions. Friends with other sideloaded apps may hit the per-device limit. |
| **Every install needs Nelson's Mac** | Nobody can install or update alone | Install sessions (Tue 11/10, ~11/15–16); updates over Wi-Fi |

Background location, background uploads, the photo library, local notifications, Live Activities (updated by the app) and Siri shortcuts all work with free signing.

**Developer Mode note:** it lowers some protections on the phone. It can be turned off again after the trip (Settings → Privacy & Security → Developer Mode), though the app then stops opening.

## 4. Design parity

Nothing is shared automatically with the web, so parity comes from **shared tokens + matching components + side-by-side checks**.

### 4.1 Tokens

`design/tokens.json` becomes the single source of colors, radii, shadows, spacing and font roles. A small Node script generates:

- `web/src/tokens.css`: the CSS variables `app.css` uses today
- `ios/CuritibaTrip/DesignSystem/Theme.swift`: `Color.sea`, `Color.sun`, `Radius.card`, …

CI fails if the generated files are out of date.

### 4.2 Fonts and icons

- **Fredoka** (titles, buttons) and **Nunito** (body) are bundled in the app. Both are SIL Open Font License and free to embed. Sizes map to Dynamic Type so people's text-size settings are respected.
- The **icons** from `web/src/lib/components/Icon.svelte` (same SVG paths) are exported into the asset catalog as template SVGs, via `Icon(.pin)` in SwiftUI.

### 4.3 Components (web → SwiftUI)

| Web | SwiftUI |
|---|---|
| `.btn` (chunky, presses down) | `ChunkyButtonStyle(.sun / .sea / .leaf / .secondary / .danger)`: bottom shadow, 3 pt press offset, haptic |
| `.card`, `.bubble` | `CardModifier`, `BubbleShape` (with the speech tail) |
| `.chip`, day "stamp" chips | `Chip`, `StampChip` (dashed border) |
| Dotted background | `DottedBackground` (`Canvas`) |
| Header + floating dock | `TopBar` + a custom `Dock` (not the system tab bar: same tiles, raised yellow "Enviar") |
| Wooden day sign | `DaySign` |
| `Avatar` (photo or initials + color ring) | `AvatarView` |
| `Post` (carousel, double-tap heart, liked-by) | `PostView` (`TabView(.page)`, double-tap gesture, `LikeButton`, `LikedBy`) |
| `CheckinPost` (map picture) | `CheckinPostView` |
| `UploadFlight` (plane on the dotted route, "Chegou!" stamp, confetti) | `UploadFlightView` (`Canvas` + `TimelineView`) |
| Map markers (polaroids, pins that drop, bobbing people) | MapLibre annotation views with the same animations |
| `AvatarCropper` (circle framer) | `AvatarCropperView` (drag, pinch, slider) |
| Passport login | `LoginView` (passport card, clouds, plane) |

### 4.4 Motion and feel

- The web's `--bounce` curve becomes `.spring(response: 0.45, dampingFraction: 0.6)`. Pop-in, pin drop with ripple, stamp, plane flight and heart burst are rebuilt with the same timings.
- Haptics: `.sensoryFeedback` on presses, likes, check-ins and finished uploads.
- **Reduce Motion** turns off the decorative animations (as the web does).
- **Dark only, Portuguese (pt-BR) only.**

### 4.5 Parity checks

For every screen, capture web (375 pt) and iOS (iPhone 15/16 size) side by side in the PR description. Differences get fixed or explicitly accepted.

## 5. Backend changes (in `web/`, first)

These ship as normal PRs: CI, merge, automatic deploy. The web app also moves onto these endpoints where it helps (feed paging).

### 5.1 Auth with tokens

- `GET /api/auth/people`: the "Quem é você?" list (id, name, color, photo).
- `POST /api/auth/code` `{ userId }` → `{ maskedEmail }`
- `POST /api/auth/verify` `{ userId, code, deviceName }` → `{ token, user }`
- `POST /api/auth/logout` revokes this device's token.
- `hooks.server.ts` accepts `Authorization: Bearer <token>` as well as the cookie. Same `sessions` table (sha256 of the token), adding `kind` (`cookie` or `device`) and `deviceName`. `/mais` lists the devices and can revoke them.

### 5.2 JSON endpoints

| Endpoint | Notes |
|---|---|
| `GET /api/me` | Includes `minAppVersion`. |
| `GET /api/activity?since=` | What's new for me, used for local notifications (§5.5). |
| `GET /api/people` | |
| `GET /api/feed?before=<cursor>&limit=30&day=&person=` | **Paginated**, newest first, already grouped into posts (carousels) so the web and iOS group the same way. The web feed switches to it. |
| `GET /api/map?day=` | Pins, check-ins, trails and latest positions. |
| `GET/PATCH/DELETE /api/media/:id` | Caption, location fix, delete (today these are form actions). |
| `GET/POST /api/media/:id/comments`, `GET/POST /api/checkins/:id/comments`, `DELETE /api/comments/:id` | |
| `PATCH /api/checkins/:id` | Edit the note (deleting exists already). |
| `GET /api/itinerary` | Moves `itinerary.ts` into data, which also takes it out of the public repo. |
| `GET /api/map-style.json?theme=night` | The style from `map-style.ts`, so MapLibre Native draws the identical map. |
| `GET/POST/PATCH/DELETE /api/admin/users` | The admin page as JSON. |

Unchanged: `/api/uploads*`, `/api/likes`, `/api/checkins` (create), `/api/checkins/:id/snapshot`, `/api/users/:id/avatar`, `/api/locations`.

### 5.3 Uploads from the photo library

- A `clientAssetId` (the photo library's local ID) with a unique index per person, so retries and auto-import never duplicate a post.
- The capture time and location come from the `PHAsset`, with `locationSource: 'device-library'`. The worker still reads the file's metadata and keeps the better value.

### 5.4 Background location

- `POST /api/locations/batch` `[{ lat, lng, accuracy, at }]`. Client times are accepted only within the last 48 hours, never in the future, and thinned (≥30 m or ≥3 min apart).

### 5.5 Notifications without push

Free signing has no APNs, so the app notifies **locally**:

- `GET /api/activity?since=<timestamp>` returns what's new for me: posts by others (grouped), comments on my posts, likes on my posts and new check-ins.
- The app checks it when iOS wakes it up: background refresh (`BGAppRefreshTask`, timing decided by iOS), background location updates (when location sharing is on, roughly every few hundred meters) and when the app opens. It then shows grouped local notifications: "Bruna e Carlos postaram 7 fotos", "Icaro comentou na sua foto".
- Itinerary reminders ("Ópera de Arame em 30 min") are **scheduled locally** from `/api/itinerary`, so they're exact.
- **Expectation:** server events arrive with a delay of minutes to hours, not instantly. If the paid program is ever added, real push can be added on top of the same `/api/activity` data.

### 5.6 Version check

- `/api/me` returns `minAppVersion`. Builds older than that show "Nova versão disponível: fale com o Nelson para atualizar", so nobody stays on a broken build.

## 6. Screens (MVP = before the trip)

| Screen | Web route | MVP | Notes |
|---|---|---|---|
| Login (passport, pick a person, code) | `/login` | ✅ | The code field autofills from Mail (`.oneTimeCode`). |
| Diário (feed) | `/` | ✅ | Paging, carousels, double-tap like, liked-by, filters by day and person |
| Photo / video detail + comments | `/m/:id` | ✅ | Full screen, zoom, video player, download the original to Photos |
| Check-in detail + comments | `/c/:id` | ✅ | |
| Enviar (upload) | `/enviar` | ✅ | Native photo library picker; flight animation per file |
| Mapa (+ check-in, live sharing) | `/mapa` | ✅ | MapLibre Native, the same markers and trails |
| Roteiro (+ Uber, Google Maps) | `/roteiro` | ✅ | Boarding-pass tickets; Uber deep link opens the Uber app directly |
| Mais (profile photo with circle cropper, location, devices, sign out) | `/mais` | ✅ | |
| Pessoas (admin) | `/admin` | ⏳ | Until then: an "Abrir no site" link |
| Edit caption / fix location | (on detail) | ⏳ | Until then: opens the web page in an in-app browser |

## 7. Native features

| # | Feature | What it does | When |
|---|---|---|---|
| 1 | **Location in the background** | The map works with the app closed (battery-friendly modes); each person's daily trail draws itself. Off by default, one switch in Mais. | MVP |
| 2 | **Photo library with location** | Picks originals (HEIC/HEVC) with location and capture time straight from PhotoKit. No GPS stripping, full quality. | MVP |
| 3 | **Uploads that finish in your pocket** | A background `URLSession`: close the app and it keeps uploading. | MVP |
| 4 | **Activity notifications** | Local notifications from background checks, plus exact itinerary reminders (§5.5). Not instant. | MVP |
| 5 | **"Fotos de hoje" auto-import** | Each evening it lists the day's photos taken in Curitiba; post the ones you pick in one tap. | MVP if time allows, otherwise in the first update |
| 6 | **Arrival check-ins** | Geofences around the itinerary stops trigger "Chegou no Jardim Botânico! Fazer check-in?" | First update |
| 7 | **Share Extension** | "Viagem" in the Photos share sheet (only if free teams can share the login, §3) | First update |
| 8 | **Live Activity / Dynamic Island** | The next stop with a countdown and transport; on the wedding day, the ride home (updated by the app, no push) | During the trip |
| 9 | **Widgets** | Countdown to the wedding, the next stop, the group's latest photo | During the trip |
| 10 | **Câmera da viagem** | An in-app camera with a passport-stamp frame that posts straight away | During the trip |
| 11 | **Offline mode** | Posts and check-ins queue without signal; the itinerary and map kept for offline use | During the trip |
| 12 | **Siri / Action button** | "Fazer check-in na viagem" | Later |
| 13 | ~~Wallet pass~~ | Not possible with free signing | — |
| 14 | **Retrospectiva** | A recap video of everyone's moments, made on the phone | After |

Check-in map pictures: the app uses MapLibre's native snapshotter with the same style, pin, label and attribution as the web version, uploaded to the existing snapshot endpoint.

### Privacy

- Background location is **off by default**, stoppable any time, and visible only to the group. Add an option to delete your location history.
- Auto-import only **suggests**; nothing is posted without a tap.
- Each type of notification can be turned off.

## 8. Project layout

```
ios/
  PLAN.md · README.md
  project.yml                  ← XcodeGen spec (targets, packages, capabilities, signing settings)
  CuritibaTrip/
    App/                       ← CuritibaTripApp, AppState, RootView, deep links, notification delegate
    DesignSystem/
      Theme.swift              ← generated from design/tokens.json
      Fonts/ (Fredoka, Nunito) · Icons.xcassets
      Components/              ← ChunkyButtonStyle, Card, Bubble, Chip, StampChip, AvatarView,
                                 DottedBackground, Dock, TopBar, DaySign, Stamp, UploadFlightView
    Features/
      Login/ Feed/ Post/ MediaDetail/ Checkin/ Upload/ Map/ Roteiro/ More/ Admin/
    Services/
      APIClient.swift · Auth (Keychain) · Uploader (background URLSession)
      LocationService · PushService · PhotoLibrary · MapStyle
    Models/                    ← Codable types matching the API
    Resources/                 ← Assets.xcassets, Localizable.xcstrings (pt-BR)
  ShareExtension/              ← later
  Widgets/                     ← later (WidgetKit + Live Activity)
  CuritibaTripTests/
design/
  tokens.json
```

Bundle IDs: `com.nelsul.curitibatrip` (+ `.share`, `.widgets` if free signing allows them, §3), plus an App Group: `group.com.nelsul.curitibatrip` (to verify).

## 9. Timeline

This is aggressive. If something slips, the website covers it, and the app gets an update at the next install session.

| When | What |
|---|---|
| **Sat 11/07** | Backend PRs: token auth (5.1), JSON endpoints, feed paging, itinerary, map style, `/api/activity` (5.2, 5.5), upload dedup and batched locations (5.3–5.4). Design tokens (4.1). App skeleton: XcodeGen, theme, fonts, icons, components, `APIClient`, login. **Day-1 check:** what free signing allows (App Groups, extensions) on Nelson's iPhone. |
| **Sun 11/08** | Feed, post, detail, comments, likes; Enviar with the photo library and background upload; Mapa with MapLibre, check-in and live sharing. |
| **Mon 11/09** | Roteiro, Mais (cropper, location switch), background location, local notifications and reminders. Test on Nelson's iPhone + 1 more. |
| **Tue 11/10 (evening)** | **Install session:** everyone's iPhone on Nelson's Mac (§3). Pair Wi-Fi installs for later. As late as possible, so the 7 days last longer. |
| 11/11–14 | Updates over Wi-Fi when the Mac and phones share a network: auto-import, arrival check-ins, Live Activity, widgets, camera, offline. |
| **~11/15–16** | **Re-install session** (expiry is ~11/17). |
| After | Siri, Retrospectiva. |

**Cut order if late:** auto-import → local notifications → the Mais extras. Never cut: login, feed, upload, map, check-in, itinerary.

## 10. Testing

- **Backend:** the `check` CI on every PR. Add API tests (Vitest + a Postgres service in CI) for tokens, paging, upload dedup and location batching.
- **iOS:** unit tests for API decoding, chunk math and the upload resume logic. Run on the simulator (Xcode 27 / iOS 27 available) and **2+ real iPhones**, including one older model on the lowest supported iOS.
- **Real-world:** a weak network, Airplane Mode for the queue, Low Power Mode, the app closed during an upload and during location tracking, and a half-day battery walk before the trip.
- **Parity:** web vs. iOS screenshots per screen (§4.5).

## 11. Risks

| Risk | Mitigation |
|---|---|
| The app expires 7 days after install | A late install on 11/10 + a re-install session ~11/15–16 (Wi-Fi if the Mac travels); the website as fallback. |
| Every install needs Nelson's Mac | Install sessions; Wi-Fi pairing; whoever misses it uses the website. |
| Free-team limits on extensions and App Groups | Verified on day 1; extensions are optional. |
| A full SwiftUI rebuild in 4 days | MVP cut order (§9); the website is the fallback; updates during the trip from the same link. |
| A friend's iPhone runs iOS < 17 | Check everyone's iOS version this weekend; lower the target only if needed. |
| The design drifts from the web | Shared tokens + generated `Theme.swift`, the same icons and fonts, screenshot checks. |
| Background location drains batteries | Significant-change and visit tracking only; an easy off switch. |
| Duplicate uploads | `clientAssetId` unique per person. |
| Secrets in a public repo | Signing stays in Nelson's Xcode/keychain (nothing to commit); `.gitignore` covers `*.p8`, `*.p12`, `*.cer` and `*.mobileprovision`. |

## 12. Android?

SwiftUI is iOS-only. For an Android friend, the website keeps working. A native Android app would be a separate Kotlin/Compose project on the same API from §5. Publishing on Google Play needs a **one-time US$25** developer registration. You could also just share the APK file directly, with no fee and no store.

## 13. Still to confirm

1. Who's getting the app, and each iPhone's **iOS version** (minimum iOS 17).
2. **Will the Mac come to Curitiba?** That decides the mid-trip re-install (§3).
3. The bundle ID `com.nelsul.curitibatrip`.
4. The MVP scope in §6/§7.
