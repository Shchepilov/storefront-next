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

# --- Default storefront configuration ---------------------------------------
# `sfnext preview` does not read .env files, and config.server.ts ships empty
# api defaults, so without these the server dies at boot with
# "Missing clientId in config.server.ts commerce.api configuration".
#
# These are the PUBLIC zzrf-041 demo values already committed in .env.default,
# not secrets. They are only defaults: any variable set on the hosting service
# (Render env vars, `docker run -e`) overrides the image ENV.
#
# Caveat: this trades a loud boot failure for a silent fallback to the demo
# backend. When you point this at a real instance, override all five.
ENV PUBLIC__app__commerce__api__clientId="b7e5e42d-7169-4325-8c52-e142142a821c"
ENV PUBLIC__app__commerce__api__organizationId="f_ecom_zzrf_041"
ENV PUBLIC__app__commerce__api__shortCode="8o7m175y"
ENV PUBLIC__app__defaultSiteId="MarketStreet"
ENV PUBLIC__app__commerce__sites="[{\"cookies\":{\"domain\":null},\"id\":\"MarketStreet\",\"alias\":\"Sites-MarketStreet-Site\",\"name\":\"Sites-MarketStreet-Site\",\"defaultLocale\":\"en-US\",\"defaultCurrency\":\"USD\",\"supportedLocales\":[{\"id\":\"en-US\",\"preferredCurrency\":\"USD\"},{\"id\":\"en-GB\",\"preferredCurrency\":\"USD\"}],\"supportedCurrencies\":[\"USD\",\"GBP\"]}]"

# The preview server loads config.server.ts (via jiti + tsconfig paths) at
# startup, so the project sources must stay in the image alongside build/.
COPY --from=build /app /app
EXPOSE 3000
# `sfnext preview` defaults to port 3000 and does not read $PORT, so pass it.
CMD ["sh", "-c", "EXTERNAL_DOMAIN_NAME=${EXTERNAL_DOMAIN_NAME:-${RENDER_EXTERNAL_HOSTNAME:-localhost:${PORT:-3000}}} pnpm start --port ${PORT:-3000}"]
