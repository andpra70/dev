# Vite Login App

Piccola app React + Vite con login demo e pagina Hello World.

## Avvio

```bash
npm install
npm run dev
```

Credenziali demo: `demo` / `password123`.

> Il login è simulato nel browser ed è pensato solo come demo. In produzione le credenziali devono essere verificate da un backend sicuro.

## Servizi Docker

Il file `compose.yaml` avvia MongoDB, PostgreSQL e Redis con volumi persistenti e healthcheck.

```bash
cp .env.example .env
docker compose up -d
docker compose ps
```

Connessioni predefinite:

- MongoDB: `mongodb://admin:mongo_password@localhost:27017/app?authSource=admin`
- PostgreSQL: `postgresql://app:postgres_password@localhost:5432/app`
- Redis: `redis://:redis_password@localhost:6379`

Modifica `.env` per cambiare credenziali o porte. Per fermare i servizi usa `docker compose down`; aggiungi `-v` soltanto se vuoi eliminare anche tutti i dati persistenti.

## Immagine Docker e Gitea Actions

Il `Dockerfile` compila l'app Vite in uno stage Node e pubblica i file statici
con Nginx non-root sulla porta `8080`.

Test locale:

```bash
docker build -t vite-login-app:test .
docker run --rm -p 127.0.0.1:8081:8080 vite-login-app:test
```

Il workflow `.gitea/workflows/container.yml` viene eseguito a ogni push, sui
tag `v*` e manualmente. Pubblica nel Container Registry Gitea:

```text
gitea:3000/<proprietario>/<repository>:<commit>
gitea:3000/<proprietario>/<repository>:<branch-o-tag>
gitea:3000/<proprietario>/<repository>:latest
```

`latest` viene aggiornato soltanto dalla branch predefinita. Prima del primo
push creare in Gitea un access token con permesso di scrittura sui package e
aggiungere in **Repository → Settings → Actions → Secrets**:

- `REGISTRY_USER`: nome dell'utente proprietario del token;
- `REGISTRY_TOKEN`: access token Gitea.

I valori non devono essere salvati nel repository o nel file workflow.
