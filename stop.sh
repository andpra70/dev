#!/usr/bin/env bash
set -euo pipefail

# I volumi non vengono cancellati: workspace, configurazione ed estensioni persistono.
docker compose -f "$(dirname "$0")/compose.yml" down

docker compose -p dev down --remove-orphans
