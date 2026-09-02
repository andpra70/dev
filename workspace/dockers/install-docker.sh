#!/usr/bin/env bash

set -Eeuo pipefail

readonly DOCKER_KEYRING='/etc/apt/keyrings/docker.asc'
readonly DOCKER_SOURCE='/etc/apt/sources.list.d/docker.sources'

log() {
  printf '\n==> %s\n' "$*"
}

die() {
  printf 'Errore: %s\n' "$*" >&2
  exit 1
}

if [[ ! -r /etc/os-release ]]; then
  die 'Impossibile identificare il sistema operativo.'
fi

# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == 'debian' ]] || die 'Questo script supporta esclusivamente Debian.'

if (( EUID == 0 )); then
  SUDO=()
else
  command -v sudo >/dev/null 2>&1 || die 'Installa sudo oppure esegui lo script come root.'
  SUDO=(sudo)
fi

command -v apt-get >/dev/null 2>&1 || die 'apt-get non è disponibile.'
command -v dpkg >/dev/null 2>&1 || die 'dpkg non è disponibile.'

log 'Installazione dei prerequisiti'
"${SUDO[@]}" apt-get update
"${SUDO[@]}" apt-get install -y ca-certificates curl

log 'Configurazione del repository ufficiale Docker'
"${SUDO[@]}" install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  | "${SUDO[@]}" tee "$DOCKER_KEYRING" >/dev/null
"${SUDO[@]}" chmod a+r "$DOCKER_KEYRING"

architecture="$(dpkg --print-architecture)"
codename="${VERSION_CODENAME:-}"
[[ -n "$codename" ]] || die 'VERSION_CODENAME non è definito in /etc/os-release.'

printf '%s\n' \
  'Types: deb' \
  'URIs: https://download.docker.com/linux/debian' \
  "Suites: $codename" \
  'Components: stable' \
  "Architectures: $architecture" \
  "Signed-By: $DOCKER_KEYRING" \
  | "${SUDO[@]}" tee "$DOCKER_SOURCE" >/dev/null

log 'Installazione di Docker Engine e Docker Compose'
"${SUDO[@]}" apt-get update
"${SUDO[@]}" apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

log 'Avvio del servizio Docker'
if command -v systemctl >/dev/null 2>&1; then
  "${SUDO[@]}" systemctl enable --now docker
else
  "${SUDO[@]}" service docker start
fi

log 'Verifica installazione'
"${SUDO[@]}" docker version
"${SUDO[@]}" docker compose version

printf '\nInstallazione completata. Avvia lo stack con:\n\n'
if (( EUID == 0 )); then
  printf '  docker compose -f /workspace/dockers/compose.yaml up -d\n'
else
  printf '  sudo docker compose -f /workspace/dockers/compose.yaml up -d\n'
fi
printf '\n'
