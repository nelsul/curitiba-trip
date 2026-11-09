# API (for the iOS and Android apps)

Base URL: `https://viagem.nelsul.com`. JSON in and out. Errors are `{ "message": "…" }` with a 4xx/5xx status, and the message is in Portuguese, ready to show to the person.

## Auth

The website uses a session cookie. The iOS and Android apps send **`Authorization: Bearer <token>`** on every request (and `x-app-version`). Both map to the same `sessions` table, which stores only a SHA-256 of the token. Sessions last 60 days and are extended while in use.

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

Store the token securely: the **Keychain** on iOS, a Keystore-encrypted value on Android. On `401`, clear it and show the login. If the app's version is lower than `minAppVersion`, show "Nova versão disponível: fale com o Nelson para atualizar".

`photo` URLs are presigned R2 links, valid for about 1–2 days. Cache the images, but refresh the URLs from the API.

## Uploads, likes, check-ins, locations, avatars

| Method | Path | Notes |
|---|---|---|
| POST | `/api/uploads` | Start a multipart upload: `{ name, size, type, takenAt, takenAtSource, lat, lng, locationSource, caption }` → `{ id, partSize, partCount }` |
| POST | `/api/uploads/:id/parts` | `{ parts: [1, 2, …] }` (max 50 per call) → `{ urls: { "1": "https://…r2…" } }`. `PUT` each chunk (`partSize` bytes, the last one shorter) to its URL and keep the `ETag` response header. |
| PUT | `/api/uploads/:id/preview` | Body: a small JPEG/WebP/PNG (≤ 1.5 MB; the apps send ~720 px) while the original waits for Wi‑Fi. The post shows up in the feed right away with `status: 'preview'` and this picture; the processed original replaces it. Starting the same `clientAssetId` again restarts the original upload in place (same id, likes and comments kept; the reply has `preview: true`). |
| POST | `/api/uploads/:id/complete` | `{ parts: [{ n, etag }] }` → `{ ok }`; the worker then processes it |
| DELETE | `/api/uploads/:id` | Cancel an unfinished upload |
| POST | `/api/likes` | `{ mediaId \| checkinId, liked }` → `{ likers: [userId] }` |
| POST | `/api/checkins` | `{ lat, lng, accuracy, note }` → `{ id }` |
| DELETE | `/api/checkins/:id` | Your own, or anyone's if you're an admin |
| PUT | `/api/checkins/:id/snapshot` | Body: the map picture (WebP/JPEG/PNG, ≤ 1.5 MB) |
| GET / POST | `/api/locations` | Latest position per person / send my position `{ lat, lng, accuracy }` |
| PUT / DELETE | `/api/users/:id/avatar` | Body: a square image (≤ 1 MB). Yourself, or anyone if you're an admin. |

## Feed, map and details

| Method | Path | Notes |
|---|---|---|
| GET | `/api/feed?limit=20&before=&day=&person=` | → `{ posts, nextCursor, days }`. A media item can have `status: 'preview'` (only the low-res picture so far, the original waits for the sender's Wi‑Fi). Newest first. Each post is `{ type: 'media', key, userId, day, at, items: [FeedMedia] }` (a carousel: same person, same day, ≤30 min apart, oldest→newest inside) or `{ type: 'checkin', key, userId, day, at, item }`. Pass `nextCursor` as `before` for the next page (`null` = end). `limit` is 1–100. `days` lists every day that has posts (whatever the filters), for the day chips. The web Diário pages through this endpoint too, and refreshes by asking for as many posts as it has loaded. |
| GET | `/api/feed/media?day=&person=` | → `{ media: [FeedMedia] }`: every ready photo/video, newest first, in one response (the "Todas as fotos" grid and its reels). |
| GET | `/api/map?day=` | → `{ items, pings, latest }`: located posts and check-ins, and everyone's latest position. `day` (YYYY-MM-DD, Curitiba time) limits the items. `pings` is always `[]`: trails were removed (background positions weren't reliable enough); the field stays for older apps. |
| GET | `/api/media/:id` | → `{ item, comments, likers }`. `item` has `display` (2048 px), `medium` (1080 px), `video`, `poster` and `original` (download) URLs. |
| PATCH | `/api/media/:id` | Owner: `{ caption?, lat?, lng? }` (lat+lng = manual location) → the updated item |
| DELETE | `/api/media/:id` | Owner or admin: removes the post and all its files |
| GET | `/api/media/:id/file` | The feed-size picture (photo, or video poster) from our own origin, so the website can draw it on a canvas (share frames). The apps use the `image` URL directly. |
| GET | `/api/checkins/:id` | → `{ item, comments, likers }` (`item.snapshot` = the map picture) |
| PATCH | `/api/checkins/:id` | Owner: `{ note }` → the updated item |
| GET / POST | `/api/media/:id/comments`, `/api/checkins/:id/comments` | List, or `{ body }` → the new comment (201). `@Full Name` (or `@FirstName` when only one person has it; accents and case don't matter) mentions someone: they get it in `/api/activity` `mentions`. |
| DELETE | `/api/comments/:id` | Your own, or anyone's if you're an admin |
| GET | `/api/itinerary` | → `{ transport, days }`, where each stop has `place` (name, lat, lng, hours, `mapsUrl`, `uberUrl`, plus `category`, `price`, `photo`) and `visited`, and each day has a `routeUrl`. Built from the editable Roteiro below; used by the apps for reminders and arrival alerts. |
| GET | `/api/places?q=&lat=&lng=` | Place search for marking where a photo/video was taken → `[{ name, detail, lat, lng }]` (max 10). `q` is 2–100 chars; results are ranked near `lat`/`lng` (send the map's center; default Curitiba), itinerary places first. OpenStreetMap data via Photon; `502` if it doesn't answer. |
| GET | `/api/map-style.json` | The island night MapLibre style (the same as the web map). Cache for an hour. |

## Cotinha, Retrospectiva, the couple, weather

| Method | Path | Notes |
|---|---|---|
| GET | `/api/splits` | → `{ splits: [{ id, title, totalCents, payerId, pixKey, note, createdAt, remindedAt, shares: [{ userId, amountCents, paidAt }] }], myPix }`. Newest first. `myPix` = my saved Pix key (to prefill; saved whenever I create a cotinha with one). |
| POST | `/api/splits` | `{ title, totalCents, pixKey?, note?, participants: [userId] }` (equal parts; leftover cents go to the first people) or `shares: [{ userId, amountCents }]` adding up to `totalCents` → `{ id }` (201). I'm the payer; my own part starts paid. |
| DELETE | `/api/splits/:id` | The payer or an admin |
| POST | `/api/splits/:id/paid` | `{ userId?, paid }`: my own part, or anyone's when I'm the payer (or admin) |
| POST | `/api/splits/pay-all` | `{ payerId }`: "Paguei tudo", every part I still owe that person is marked paid (they get the `splitPaid` notifications) → `{ parts, totalCents }` |
| POST | `/api/splits/:id/remind` | The payer: everyone who hasn't paid gets a notification (`/api/activity` `splits`, kind `reminder`). At most every 10 min (429). |
| GET | `/api/retro` | → `{ weddingAt, items: [FeedMedia] }`: the countdown target and the admin's picks, in order. Clients show the countdown until `weddingAt`, then the picks as stories (admins can preview before). |
| PUT | `/api/admin/retro` | Admin: `{ mediaIds: [...] }` replaces the list, in this order (max 300) |
| GET | `/api/couple-likes` | → `{ likes: [{ id, likerId, role: noivo\|noiva, mediaId, checkinId, at, image }] }`: likes from the bride/groom on my posts I haven't seen the special effect for (max 20, oldest first) |
| POST | `/api/couple-likes/seen` | `{ upTo: likeId }` after showing the effect |
| PUT | `/api/admin/users/:id/couple` | Admin: `{ couple: 'noivo' \| 'noiva' \| null }` (also on the website's /admin) |
| GET | `/api/weather` | → `{ days: [{ date, min, max, rain, kind, hours: [{ time: "HH:MM", temp, rain, kind }] }], updatedAt }` for the trip days the forecast reaches (Open-Meteo, cached 30 min). `kind`: sun, partly, cloud, fog, rain, storm (the icons of the same names). `rain` = chance in %. Empty when the service is down. |

## Roteiro (the same for everyone; only admins change places and days)

Everyone reads the Roteiro and ticks "Fomos!". Changing places, their photos and the days (`POST`/`PATCH`/`PUT`/`DELETE` under `/api/roteiro/places` and `/api/roteiro/days`) is for admins only (403 otherwise).

| Method | Path | Notes |
|---|---|---|
| GET | `/api/roteiro` | → `{ places, stays, days }`. Stay: see Hospedagem below. Each day also has `startStay` / `endStay`: the id of the stay the person asking wakes up in / sleeps in that day (or null). Place: `{ id, name, category: comer\|passeio\|outro, lat, lng, address, hours, price, priceLevel (0–4 or null), description, link, googlePlaceId, photos: [{ id, url }] }`. Day: `{ date, title, who, lead, wedding, stops: [{ id, time, placeId, label, transport, note, visitedAt, visitedBy }] }` |
| POST | `/api/roteiro/places` | Place fields (name, category, lat, lng required) → `{ id }` (201) |
| PATCH / DELETE | `/api/roteiro/places/:id` | Edit, or delete (stops that used it keep its name as `label`) |
| POST | `/api/roteiro/places/:id/photos` | Body: one image (JPG/PNG/WebP, ≤ 2 MB; the apps send 1600 px JPEG) → `{ id, url }`. Max 12 per place. |
| DELETE | `/api/roteiro/places/:id/photos/:photoId` | |
| PUT | `/api/roteiro/days/:date` | `{ title, who, lead, wedding, stops: [{ id?, time, placeId \| label, transport, note }] }` replaces the day, stops in the order sent. Send each existing stop's `id` so its "Fomos!" tick is kept. Times like `9h35` or `14h` get the apps' 30-min reminder. |
| DELETE | `/api/roteiro/days/:date` | |
| GET | `/api/roteiro/days/:date/route` | → `{ legs: [{ transport, coordinates: [[lng, lat]…], routed, back }] }`: the street route between consecutive stops with places (OpenStreetMap routing; `routed: false` = straight line). With `?casa=1` it also starts at the asker's morning stay and ends at their night stay (the way back by the last leg's transport, Uber after Linha Turismo/Graciosa; that leg has `back: true` and the apps draw it dotted). |
| POST | `/api/roteiro/stops/:id/visited` | `{ visited }` → `{ visitedAt, visitedBy }`. "Fomos!": one tick counts for the whole group. |

### Hospedagem (admins only)

Where people sleep. Everyone reads them in `GET /api/roteiro`; only admins change them. A stay covers the nights from `checkIn` (first night) to the day before `checkOut` (the day they leave); null = from the start / until the end of the trip. Every day from check-in to check-out (both included) starts and ends there; on a day someone changes places, it starts at the old one and ends at the new one. Nobody can be in two stays on the same night (400).

| Method | Path | |
|---|---|---|
| GET | `/api/admin/stays` | → `{ stays: [{ id, name, kind: hotel\|airbnb\|casa, lat, lng, address, link, checkIn, checkOut, note, guests: [userId] }] }` |
| POST | `/api/admin/stays` | Stay fields (name, lat, lng required; `guests` = user ids) → `{ id }` (201) |
| PUT / DELETE | `/api/admin/stays/:id` | Replace (guest list included), or delete |

## Notifications

| Method | Path | Notes |
|---|---|---|
| GET | `/api/notifications` | → `{ items: [{ id, kind: post\|checkin\|comment\|like\|mention\|split\|paid, userId, text, body, at, mediaId, checkinId, cotinha, image, unread }], unread }`: the last 14 days of what other people did that concerns me, newest first (max 150), texts ready to show. Posts and likes are one line per person per day. `?count=1` → only `{ unread }` (the bell's badge). |
| POST | `/api/notifications/seen` | Opening the page: everything until now is read |

## For the app's background work

| Method | Path | Notes |
|---|---|---|
| GET | `/api/activity?since=<ISO>` | → `{ now, since, posts, checkins, comments, likes, mentions, splits, splitPaid }`: what *other people* did since then. `posts` is summarized per person (`photos`, `videos`); comments and likes are only on *my* posts; `mentions` = comments anywhere that @mention me; `splits` = cotinhas I still owe that were created (`kind: 'new'`) or that the payer asked about (`'reminder'`): `{ id, title, payerId, pixKey, amountCents, kind, at }`; `splitPaid` = people who marked they paid my cotinhas `{ id, title, userId, amountCents, at }`. Each call covers exactly (since, now], so store `now` and send it as the next `since`. The window is at most 7 days. Use it for local notifications. |
| POST | `/api/locations/batch` | `[{ lat, lng, accuracy?, at }]` (max 500) → `{ received, stored }`. Points recorded in the background with their real times. Points older than 48 h, in the future, with accuracy over 500 m, or within 30 m and 3 min of the previous one are dropped. |
| POST | `/api/uploads` | Also accepts **`clientAssetId`** (the PHAsset local identifier) and `locationSource: 'device-library'`. Re-sending a photo that already finished returns `{ id, duplicate: true, status }`; an unfinished earlier attempt is discarded and restarted. |

## Not in the API yet

The admin endpoints (`/api/admin/users`); the app opens `/admin` on the website meanwhile.

## Changing the API

Phones keep running the version they have until they're reinstalled, so add fields and endpoints instead of renaming or removing them. If old apps must stop working, raise `MIN_APP_VERSION` in `src/lib/server/me.ts`: `/api/me` and `/api/auth/verify` return it, and older apps show "Nova versão".
