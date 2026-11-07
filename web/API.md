# API (for the iOS app)

Base URL: `https://viagem.nelsul.com`. JSON in and out. Errors are `{ "message": "…" }` with a 4xx/5xx status, and the message is in Portuguese, ready to show to the person.

## Auth

The website uses a session cookie. The iOS app sends **`Authorization: Bearer <token>`** on every request. Both map to the same `sessions` table, which stores only a SHA-256 of the token. Sessions last 60 days and are extended while in use.

| Method | Path | Auth | Body → Response |
|---|---|---|---|
| GET | `/api/auth/people` | public | → `[{ id, name, color, photo }]`: the "Quem é você?" list (no emails) |
| POST | `/api/auth/code` | public | `{ userId }` → `{ maskedEmail }`. Emails a 6-digit code (max 1 email/min per person; asking again within the minute reuses the last code). |
| POST | `/api/auth/verify` | public | `{ userId, code, deviceName }` → `{ token, user, minAppVersion }`. A code works once, expires in 10 min, and allows 5 attempts. |
| POST | `/api/auth/logout` | ✔ | → `{ ok }`; the token stops working |
| GET | `/api/me` | ✔ | → `{ id, name, color, photo, isAdmin, minAppVersion }` |
| GET | `/api/people` | ✔ | → `[{ id, name, color, photo }]` |
| GET | `/api/devices` | ✔ | → `[{ id, deviceName, lastUsedAt, createdAt, current }]`: my signed-in apps (`id` is a short handle, not the token) |
| DELETE | `/api/devices/:id` | ✔ | → `{ ok }`; signs that device out |

Store the token in the **Keychain**. On `401`, clear it and show the login. If the app's version is lower than `minAppVersion`, show "Nova versão disponível: fale com o Nelson para atualizar".

`photo` URLs are presigned R2 links, valid for about 1–2 days. Cache the images, but refresh the URLs from the API.

## Existing endpoints (already work with Bearer)

| Method | Path | Notes |
|---|---|---|
| POST | `/api/uploads` | Start a multipart upload: `{ name, size, type, takenAt, takenAtSource, lat, lng, locationSource, caption }` → `{ id, partSize, partCount }` |
| POST | `/api/uploads/:id/parts` | `{ parts: [1, 2, …] }` (max 50 per call) → `{ urls: { "1": "https://…r2…" } }`. `PUT` each chunk (`partSize` bytes, the last one shorter) to its URL and keep the `ETag` response header. |
| POST | `/api/uploads/:id/complete` | `{ parts: [{ n, etag }] }` → `{ ok }`; the worker then processes it |
| DELETE | `/api/uploads/:id` | Cancel an unfinished upload |
| POST | `/api/likes` | `{ mediaId \| checkinId, liked }` → `{ likers: [userId] }` |
| POST | `/api/checkins` | `{ lat, lng, accuracy, note }` → `{ id }` |
| DELETE | `/api/checkins/:id` | Only your own |
| PUT | `/api/checkins/:id/snapshot` | Body: the map picture (WebP/JPEG/PNG, ≤ 1.5 MB) |
| GET / POST | `/api/locations` | Latest position per person / send my position `{ lat, lng, accuracy }` |
| PUT / DELETE | `/api/users/:id/avatar` | Body: a square image (≤ 1 MB). Yourself, or anyone if you're an admin. |

## Coming next (see `ios/PLAN.md` §5)

Feed with paging, map data, media and check-in details, comments, itinerary, map style, `/api/activity`, upload de-duplication (`clientAssetId`) and batched locations.
