# iOS app

A native iOS app for the trip, separate from the web app. **Not started yet.** This folder is where the Xcode project will live.

## Plan

- **SwiftUI**, iOS 17+.
- Talks to the same backend as the web app (`https://viagem.nelsul.com`). There's no separate server.
- Things a native app does better than the web:
  - share your location **in the background** (the website can only do it while open)
  - upload straight from the photo library **with location and original quality**
  - notifications for new posts, comments and likes

## Suggested layout

```
ios/
  CuritibaTrip.xcodeproj
  CuritibaTrip/
    App/            # @main, app state
    Features/       # Feed, Map, Upload, Roteiro, Profile
    Networking/     # API client for the web backend
    Resources/      # assets, colors (match web/src/app.css tokens), fonts (Fredoka, Nunito)
  CuritibaTripTests/
```

## Backend work needed first

The web API uses a session **cookie** after the email-code login. For the app we'll likely add:

- a token-based login (`POST /api/auth/code`, `POST /api/auth/verify` returning a bearer token)
- JSON endpoints for the feed and map (today those pages load data on the server)
- background location pings (`POST /api/locations` exists already)

These go in `web/` first; open an issue to discuss.

## Secrets

Never commit signing certificates, provisioning profiles, API keys or `.xcconfig` files with secrets. The root `.gitignore` already excludes the common ones (`*.p12`, `*.mobileprovision`, `Config/Secrets.xcconfig`, `xcuserdata/`).
