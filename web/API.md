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

## Feed, map and details

| Method | Path | Notes |
|---|---|---|
| GET | `/api/feed?limit=20&before=&day=&person=` | → `{ posts, nextCursor }`. Newest first. Each post is `{ type: 'media', key, userId, day, at, items: [FeedMedia] }` (a carousel: same person, same day, ≤30 min apart, oldest→newest inside) or `{ type: 'checkin', key, userId, day, at, item }`. Pass `nextCursor` as `before` for the next page (`null` = end). `limit` is 1–50. The web feed uses the same grouping (`$lib/feed-group`). |
| GET | `/api/map?day=` | → `{ items, pings, latest }`: located posts and check-ins, trails, everyone's latest position. `day` (YYYY-MM-DD, Curitiba time) limits items and trails. |
| GET | `/api/media/:id` | → `{ item, comments, likers }`. `item` has `display` (2048 px), `medium` (1080 px), `video`, `poster` and `original` (download) URLs. |
| PATCH | `/api/media/:id` | Owner: `{ caption?, lat?, lng? }` (lat+lng = manual location) → the updated item |
| DELETE | `/api/media/:id` | Owner: removes the post and all its files |
| GET | `/api/checkins/:id` | → `{ item, comments, likers }` (`item.snapshot` = the map picture) |
| PATCH | `/api/checkins/:id` | Owner: `{ note }` → the updated item |
| GET / POST | `/api/media/:id/comments`, `/api/checkins/:id/comments` | List, or `{ body }` → the new comment (201) |
| DELETE | `/api/comments/:id` | Only your own |
| GET | `/api/itinerary` | → `{ transport, days }`, where each stop has `place` (name, lat, lng, hours, `mapsUrl`, `uberUrl`) and each day has a `routeUrl` |
| GET | `/api/map-style.json` | The island night MapLibre style (the same as the web map). Cache for an hour. |

## For the app's background work

| Method | Path | Notes |
|---|---|---|
| GET | `/api/activity?since=<ISO>` | → `{ now, since, posts, checkins, comments, likes }`: what *other people* did since then. `posts` is summarized per person (`photos`, `videos`); comments and likes are only on *my* posts. Each call covers exactly (since, now], so store `now` and send it as the next `since`. The window is at most 7 days. Use it for local notifications. |
| POST | `/api/locations/batch` | `[{ lat, lng, accuracy?, at }]` (max 500) → `{ received, stored }`. Points recorded in the background with their real times. Points older than 48 h, in the future, with accuracy over 500 m, or within 30 m and 3 min of the previous one are dropped. |
| POST | `/api/uploads` | Also accepts **`clientAssetId`** (the PHAsset local identifier) and `locationSource: 'device-library'`. Re-sending a photo that already finished returns `{ id, duplicate: true, status }`; an unfinished earlier attempt is discarded and restarted. |

## Not in the API yet

The admin endpoints (`/api/admin/users`); the app opens `/admin` on the website meanwhile.
