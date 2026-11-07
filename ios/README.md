# iOS app

A native iOS app for the trip, separate from the web app. **Not started yet.** This folder is where the project will live.

👉 **The full plan is in [PLAN.md](PLAN.md):** approach, distribution without the App Store, backend changes, native features, project layout and timeline.

## In short

- **Capacitor shell + Swift** (iOS 17+). The screens are the web app, so the design is identical. Swift adds what a website can't do: location in the background, uploads that finish with the app closed, the photo library with original quality and location, notifications, widgets, Live Activities and the share sheet.
- It talks to the same backend as the web app (`https://viagem.nelsul.com`); there's no separate server. The backend changes it needs go in `web/` first (PLAN.md §5).
- **Not on the App Store.** Friends install it directly (PLAN.md §3).

## Secrets

Never commit signing certificates, provisioning profiles, the APNs key or `.xcconfig` files with secrets. The root `.gitignore` already excludes the common ones (`*.p8`, `*.p12`, `*.cer`, `*.mobileprovision`, `Config/Secrets.xcconfig`, `xcuserdata/`).
