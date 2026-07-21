# syntax=docker/dockerfile:1
FROM python:3.12-slim-bookworm

# Agent runtime tools. ponytail: ripgrep + node cover code-search and node-based
# tools; playwright browser and ffmpeg are skipped (heavy, optional). Need
# computer-use/browser or audio? add `RUN hermes postinstall` below.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ripgrep nodejs npm ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Deps first (cached layer), then hermes-agent itself from the bundled wheel
# with --no-deps — the pins in requirements.txt already satisfy it.
COPY requirements.txt ./
COPY deploy/hermes_agent-*.whl ./deploy/
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir --no-deps deploy/hermes_agent-*.whl

# Project-local Hermes home baked into the image (stateless deploy — no disk).
ENV HERMES_HOME=/app/.hermes
RUN mkdir -p "$HERMES_HOME" \
    && hermes config set model.provider deepseek \
    && hermes config set model.default deepseek-chat

# `serve` = headless JSON-RPC/WebSocket backend. Render injects $PORT; a public
# bind mandates auth, supplied via HERMES_DASHBOARD_BASIC_AUTH_* env vars.
ENV PORT=9119
CMD hermes serve --host 0.0.0.0 --port "$PORT"
