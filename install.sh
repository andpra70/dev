#!/usr/bin/env bash
set -euo pipefail

. .env

sudo apt-get update && sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg

curl -fsSL https://gvisor.dev/archive.key | sudo gpg --dearmor -o /usr/share/keyrings/gvisor-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/gvisor-archive-keyring.gpg] https://storage.googleapis.com/gvisor/releases release main" | sudo tee /etc/apt/sources.list.d/gvisor.list > /dev/null


sudo apt-get update && sudo apt-get install -y runsc

sudo /usr/local/bin/runsc install
sudo systemctl reload docker

docker run --rm --runtime=runsc hello-world
