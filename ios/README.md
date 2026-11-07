# iOS app

A native **SwiftUI** app for the trip (iOS 17+), separate from the web app but following its design exactly. **Not started yet.**

👉 **The full plan is in [PLAN.md](PLAN.md):** approach, installing without the App Store, design parity, backend changes, screens, native features, layout and timeline.

## In short

- **SwiftUI + MapLibre Native**, talking to the same backend as the web (`https://viagem.nelsul.com`). The backend changes it needs go in `web/` first (PLAN.md §5).
- **Same design as the web:** colors and sizes come from shared design tokens (`design/tokens.json` → `Theme.swift`), with the same fonts (Fredoka, Nunito), icons and animations.
- **Native extras:** location in the background, photo-library uploads with original quality and location that finish with the app closed, local notifications and itinerary reminders, and later widgets, Live Activities and the share sheet.
- **Not on the App Store, no paid account:** signed with a free Apple ID and installed by connecting each iPhone to Nelson's Mac (Developer Mode on). Free-signed apps expire after 7 days, so there's a re-install session mid-trip (PLAN.md §3).

## Secrets

Never commit signing certificates, provisioning profiles, the APNs key or `.xcconfig` files with secrets. The root `.gitignore` already excludes the common ones (`*.p8`, `*.p12`, `*.cer`, `*.mobileprovision`, `Config/Secrets.xcconfig`, `xcuserdata/`).
