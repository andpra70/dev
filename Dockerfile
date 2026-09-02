FROM ghcr.io/coder/code-server:4.133.0

ARG CODEX_VERSION=0.143.0

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates docker-cli docker-compose nodejs npm \
    && npm install --global "@openai/codex@${CODEX_VERSION}" \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

USER 1000:1000
