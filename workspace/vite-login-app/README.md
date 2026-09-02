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
