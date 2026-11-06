FROM node:22-bookworm-slim AS base
WORKDIR /app

FROM base AS build
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build && npm prune --omit=dev

# ---- web app ----
FROM base AS app
ENV NODE_ENV=production
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules node_modules
COPY --from=build /app/build build
COPY drizzle drizzle
COPY scripts scripts
USER node
EXPOSE 3000
CMD ["sh", "-c", "node scripts/migrate.mjs && exec node build"]

# ---- media worker ----
FROM base AS worker
RUN apt-get update \
 && apt-get install -y --no-install-recommends libvips-tools libimage-exiftool-perl ffmpeg ca-certificates \
 && rm -rf /var/lib/apt/lists/*
ENV NODE_ENV=production
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules node_modules
COPY --from=build /app/build-worker build-worker
USER node
CMD ["node", "build-worker/main.js"]
