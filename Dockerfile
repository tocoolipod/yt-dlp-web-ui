# -----------------------------------------------------------------------------
# UI BUILD (Node)
# -----------------------------------------------------------------------------
FROM node:22-slim AS ui

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /usr/src/yt-dlp-webui

COPY ./frontend ./frontend

WORKDIR /usr/src/yt-dlp-webui/frontend

RUN rm -rf node_modules
RUN pnpm install --frozen-lockfile
RUN pnpm run build

# -----------------------------------------------------------------------------
# BACKEND BUILD (Go)
# -----------------------------------------------------------------------------
FROM golang:1.22 AS build

WORKDIR /usr/src/yt-dlp-webui

COPY . .
COPY --from=ui /usr/src/yt-dlp-webui/frontend /usr/src/yt-dlp-webui/frontend

RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o yt-dlp-webui

# -----------------------------------------------------------------------------
# RUNTIME (Python + yt-dlp + ffmpeg)
# -----------------------------------------------------------------------------
FROM python:3.12-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip setuptools wheel \
    && pip install --upgrade "yt-dlp[default,curl-cffi,mutagen,pycryptodomex]"

VOLUME /downloads /config

WORKDIR /app

COPY --from=build /usr/src/yt-dlp-webui/yt-dlp-webui /app

ENV JWT_SECRET=secret

EXPOSE 3033

ENTRYPOINT ["/app/yt-dlp-webui", "--out", "/downloads", "--conf", "/config/config.yml", "--db", "/config/local.db"]
