#!/usr/bin/env bash
set -euo pipefail

. .env

git add .
git commit -a -m "Aggiornamento $(date +%Y-%m-%d)"
git push origin main
