#!/usr/bin/env bash
#
# Set up this project-local Hermes on a FRESH machine.
#
# Usage (from the project root):
#     bash deploy/install.sh
#
# Optionally pre-supply the key so it's written automatically:
#     DEEPSEEK_API_KEY=sk-xxxx bash deploy/install.sh
#
# It creates a project-local .venv and .hermes/ — nothing is installed
# system-wide. Afterwards run the agent with:  ./hermes
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../deploy
PROJECT="$(cd "$HERE/.." && pwd)"                       # project root
WHEEL="$(ls -1t "$HERE"/hermes_agent-*.whl 2>/dev/null | head -1 || true)"
PYTHON="${PYTHON:-python3.12}"
cd "$PROJECT"

echo "==> Project : $PROJECT"
echo "==> Wheel   : ${WHEEL:-<none found>}"
[ -n "$WHEEL" ] || { echo "ERROR: no hermes wheel in $HERE — cannot continue."; exit 1; }

# 1) Create the venv (prefer uv; fall back to the stdlib venv module)
if command -v uv >/dev/null 2>&1; then
  echo "==> uv found — creating venv with Python 3.12"
  uv venv "$PROJECT/.venv" --python 3.12
  PIP=(uv pip install --python "$PROJECT/.venv/bin/python")
else
  echo "==> uv not found — using $PYTHON -m venv"
  command -v "$PYTHON" >/dev/null 2>&1 || { echo "ERROR: $PYTHON not installed. Install Python 3.11–3.13 or uv."; exit 1; }
  "$PYTHON" -m venv "$PROJECT/.venv"
  "$PROJECT/.venv/bin/python" -m pip install --quiet --upgrade pip
  PIP=("$PROJECT/.venv/bin/pip" install)
fi

# 2) Install the pinned dependency libraries
echo "==> Installing dependencies from requirements.txt"
"${PIP[@]}" -r "$PROJECT/requirements.txt"

# 3) Install hermes-agent itself from the bundled wheel (no dep re-resolution)
echo "==> Installing hermes-agent from wheel (--no-deps)"
"${PIP[@]}" --no-deps "$WHEEL"

# 4) Project-local Hermes home + provider/model config
export HERMES_HOME="$PROJECT/.hermes"
mkdir -p "$HERMES_HOME"
echo "==> Configuring provider=deepseek, model=deepseek-chat"
"$PROJECT/.venv/bin/hermes" config set model.provider deepseek  >/dev/null
"$PROJECT/.venv/bin/hermes" config set model.default  deepseek-chat >/dev/null

# 5) Non-Python deps (node, browser, ripgrep, ffmpeg) — best effort, needs network
echo "==> Bootstrapping non-Python deps (hermes postinstall)"
"$PROJECT/.venv/bin/hermes" postinstall || echo "WARN: postinstall incomplete (network needed; some deps are optional)."

# 6) Secrets — write .hermes/.env if it doesn't already exist
if [ ! -f "$HERMES_HOME/.env" ]; then
  KEY="${DEEPSEEK_API_KEY:-sk-REPLACE_ME}"
  printf '# Independent Hermes instance for: %s\nDEEPSEEK_API_KEY=%s\n' "$PROJECT" "$KEY" > "$HERMES_HOME/.env"
  chmod 600 "$HERMES_HOME/.env"
  if [ "$KEY" = "sk-REPLACE_ME" ]; then
    echo ">>> ACTION NEEDED: edit $HERMES_HOME/.env and set your real DEEPSEEK_API_KEY"
  fi
fi

echo
echo "==> Done. Start the isolated, project-local Hermes with:"
echo "      cd $PROJECT && ./hermes"
