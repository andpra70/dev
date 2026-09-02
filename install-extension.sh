#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 0 ]]; then
    echo "Uso: $0" >&2
    exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
vsix_dir="$script_dir/vsix"
shopt -s nullglob
vsix_files=("$vsix_dir"/*.vsix)

if [[ ${#vsix_files[@]} -eq 0 ]]; then
    echo "Errore: nessun file .vsix trovato in $vsix_dir" >&2
    exit 2
fi

container_name=isolated_vscode

if [[ "$(docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null)" != true ]]; then
    echo "Errore: il container $container_name non è in esecuzione." >&2
    exit 1
fi

for vsix_path in "${vsix_files[@]}"; do
    vsix_name=$(basename -- "$vsix_path")
    temporary_path="/tmp/$vsix_name"
    echo "Installazione di $vsix_name..."
    docker cp "$vsix_path" "$container_name:$temporary_path"
    docker exec -u 1000:1000 "$container_name" \
        code-server --install-extension "$temporary_path" --force
done

echo "Installate ${#vsix_files[@]} estensioni nel volume persistente vscode_data."
docker exec -u 1000:1000 "$container_name" code-server --list-extensions
