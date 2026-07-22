# # syntax=docker/dockerfile:1
# FROM python:3.12-slim-bookworm

# # Agent runtime tools. ponytail: ripgrep + node cover code-search and node-based
# # tools; playwright browser and ffmpeg are skipped (heavy, optional). Need
# # computer-use/browser or audio? add `RUN hermes postinstall` below.
# RUN apt-get update && apt-get install -y --no-install-recommends \
#         ripgrep nodejs npm ca-certificates \
#     && rm -rf /var/lib/apt/lists/*

# WORKDIR /app

# # Deps first (cached layer), then hermes-agent itself from the bundled wheel
# # with --no-deps — the pins in requirements.txt already satisfy it.
# COPY requirements.txt ./
# COPY deploy/hermes_agent-*.whl ./deploy/
# RUN pip install --no-cache-dir -r requirements.txt \
#     && pip install --no-cache-dir --no-deps deploy/hermes_agent-*.whl

# # Project-local Hermes home baked into the image (stateless deploy — no disk).
# ENV HERMES_HOME=/app/.hermes
# RUN mkdir -p "$HERMES_HOME" \
#     && hermes config set model.provider deepseek \
#     && hermes config set model.default deepseek-chat

# # `serve` = headless JSON-RPC/WebSocket backend. Render injects $PORT; a public
# # bind mandates auth, supplied via HERMES_DASHBOARD_BASIC_AUTH_* env vars.
# ENV PORT=9119
# CMD hermes serve --host 0.0.0.0 --port "$PORT"


FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y curl git ca-certificates --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Official installer — skip Playwright/Chromium if the volume already
# holds a pre-authenticated profile (see Step 5); drop --skip-browser
# if the container itself needs to launch a browser at runtime.
RUN curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-browser --skip-setup

ENV PATH="/root/.hermes/hermes-agent/venv/bin:/root/.local/bin:${PATH}"
WORKDIR /root

CMD ["hermes", "gateway", "start"]