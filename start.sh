#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example. Edit MAIN_SERVER_IP and SERVER_ID, then rerun."
  exit 1
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

profiles=()

if [[ "$(uname -s)" == "Linux" ]]; then
  profiles+=(--profile linux)

  nvidia_lib="$(ls /usr/lib/x86_64-linux-gnu/libnvidia-ml.so.* 2>/dev/null | sort -V | tail -n 1 || true)"
  if [[ -e /dev/nvidia0 && -n "${nvidia_lib}" ]]; then
    export NVIDIA_ML_LIB_PATH="${NVIDIA_ML_LIB_PATH:-${nvidia_lib}}"
    profiles+=(--profile gpu)
    echo "Detected Linux NVIDIA GPU. Starting CPU + Linux exporters + GPU collector."
    echo "NVIDIA_ML_LIB_PATH=${NVIDIA_ML_LIB_PATH}"
  else
    echo "Linux detected, but NVIDIA GPU/libnvidia-ml was not found. Starting CPU + Linux exporters only."
  fi
else
  echo "Non-Linux OS detected. Starting CPU-safe collector only."
fi

docker compose "${profiles[@]}" up -d
