#!/usr/bin/env bash
set -euo pipefail

. .env

if [[ -z "${VSCODE_PASSWORD:-}" ]]; then
    echo "Errore: esportare VSCODE_PASSWORD prima dell'avvio." >&2
    exit 1
fi

docker compose -f "$(dirname "$0")/compose.yml" up -d
echo "VS Code disponibile su http://127.0.0.1:8080 (password: $VSCODE_PASSWORD)"
