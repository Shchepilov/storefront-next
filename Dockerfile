# syntax=docker/dockerfile:1

# ---- base -------------------------------------------------------------------
FROM node:24-slim AS base
ENV PNPM_HOME=/pnpm \
    PATH=/pnpm:$PATH \
    CI=true
# pnpm version comes from the "packageManager" field in package.json
RUN corepack enable
WORKDIR /app

# ---- build ------------------------------------------------------------------
FROM base AS build
COPY . .
RUN pnpm install --frozen-lockfile
ENV NODE_OPTIONS=--max-old-space-size=4096
RUN pnpm build

# ---- runtime ----------------------------------------------------------------
FROM base AS runtime
ENV NODE_ENV=production
# The preview server loads config.server.ts (via jiti + tsconfig paths) at
# startup, so the project sources must stay in the image alongside build/.
COPY --from=build /app /app
EXPOSE 3000
# `sfnext preview` defaults to port 3000 and does not read $PORT, so pass it.
CMD ["sh", "-c", "EXTERNAL_DOMAIN_NAME=${EXTERNAL_DOMAIN_NAME:-${RENDER_EXTERNAL_HOSTNAME:-localhost:${PORT:-3000}}} pnpm start --port ${PORT:-3000}"]
