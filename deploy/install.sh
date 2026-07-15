#!/usr/bin/env bash
#
# Set up this project-local Hermes on a FRESH machine (Linux, macOS, Windows/Git Bash).
#
# Usage (from the project root):
#     bash deploy/install.sh
#
# Optionally pre-supply the key so it's written automatically:
#     POSIX shell : DEEPSEEK_API_KEY=sk-xxxx bash deploy/install.sh
#     PowerShell  : $env:DEEPSEEK_API_KEY="sk-xxxx"; bash deploy/install.sh
#
# It creates a project-local .venv and .hermes/ — nothing is installed
# system-wide. Afterwards run the agent with:  ./hermes  (Windows: .\hermes.cmd)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../deploy
PROJECT="$(cd "$HERE/.." && pwd)"                       # project root
WHEEL="$(ls -1t "$HERE"/hermes_agent-*.whl 2>/dev/null | head -1 || true)"
cd "$PROJECT"

echo "==> Project : $PROJECT"
echo "==> Wheel   : ${WHEEL:-<none found>}"
[ -n "$WHEEL" ] || { echo "ERROR: no hermes wheel in $HERE — cannot continue."; exit 1; }

# Accepts only an interpreter that actually runs and is 3.11–3.13.
# Also filters out the Windows "python3" App Execution Alias, which resolves but is a stub.
py_ok() { "$1" -c 'import sys; sys.exit(0 if (3,11) <= sys.version_info < (3,14) else 1)' >/dev/null 2>&1; }

# 1) Create the venv (prefer uv; fall back to the stdlib venv module)
if command -v uv >/dev/null 2>&1; then
  echo "==> uv found — creating venv with Python 3.12"
  uv venv "$PROJECT/.venv" --python 3.12
  USE_UV=1
else
  PYTHON="${PYTHON:-}"
  if [ -z "$PYTHON" ]; then
    for c in python3.12 python3.13 python3.11 python3 python; do
      if command -v "$c" >/dev/null 2>&1 && py_ok "$c"; then PYTHON="$c"; break; fi
    done
  fi
  [ -n "$PYTHON" ] || { echo "ERROR: no Python 3.11–3.13 found. Install one, or install uv."; exit 1; }
  echo "==> uv not found — using $PYTHON -m venv"
  "$PYTHON" -m venv "$PROJECT/.venv"
  USE_UV=
fi

# Windows venvs put executables in Scripts/ and suffix them .exe; POSIX uses bin/ and no suffix.
# uv resolves --python literally, so the suffix is required — "Scripts/python" does not exist.
if [ -d "$PROJECT/.venv/Scripts" ]; then
  VENV_BIN="$PROJECT/.venv/Scripts"; EXE=".exe"
else
  VENV_BIN="$PROJECT/.venv/bin"; EXE=""
fi

if [ -n "$USE_UV" ]; then
  PIP=(uv pip install --python "$VENV_BIN/python$EXE")
else
  "$VENV_BIN/python$EXE" -m pip install --quiet --upgrade pip
  PIP=("$VENV_BIN/pip$EXE" install)
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
"$VENV_BIN/hermes$EXE" config set model.provider deepseek  >/dev/null
"$VENV_BIN/hermes$EXE" config set model.default  deepseek-chat >/dev/null

# 5) Non-Python deps (node, browser, ripgrep, ffmpeg) — best effort, needs network
echo "==> Bootstrapping non-Python deps (hermes postinstall)"
"$VENV_BIN/hermes$EXE" postinstall || echo "WARN: postinstall incomplete (network needed; some deps are optional)."

# 6) Secrets — write .hermes/.env if it doesn't already exist
if [ ! -f "$HERMES_HOME/.env" ]; then
  KEY="${DEEPSEEK_API_KEY:-sk-REPLACE_ME}"
  printf '# Independent Hermes instance for: %s\nDEEPSEEK_API_KEY=%s\n' "$PROJECT" "$KEY" > "$HERMES_HOME/.env"
  chmod 600 "$HERMES_HOME/.env" 2>/dev/null || true   # no-op on Windows filesystems
  if [ "$KEY" = "sk-REPLACE_ME" ]; then
    echo ">>> ACTION NEEDED: edit $HERMES_HOME/.env and set your real DEEPSEEK_API_KEY"
  fi
fi

echo
echo "==> Done. Start the isolated, project-local Hermes with:"
if [ -d "$PROJECT/.venv/Scripts" ]; then
  echo "      cd $PROJECT && .\\hermes.cmd     (PowerShell/cmd)"
  echo "      cd $PROJECT && ./hermes          (Git Bash)"
else
  echo "      cd $PROJECT && ./hermes"
fi
