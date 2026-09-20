# VS Code isolato con gVisor

Questo stack esegue `code-server` con `runsc`, un daemon Docker-in-Docker
dedicato e servizi persistenti Gitea, PostgreSQL, Redis e MongoDB. VS Code è
esposto tramite il reverse proxy e monta dall'host esclusivamente
`vscode-isolated/workspace`; configurazione ed estensioni vivono in volumi
Docker separati e non modificano `~/.vscode` o `~/.config/Code` dell'host.

VS Code può accedere a Internet e ai servizi dello stack attraverso la rete
privata `vscode_docker`, ma non può risalire dal mount `/workspace` alle altre
directory host. Le interfacce web sono pubblicate da un unico reverse proxy;
i container applicativi restano sulla rete privata.
La rete usa il nome Docker stabile `vscode-isolated_vscode_docker`, così un
diverso `COMPOSE_PROJECT_NAME` non prova a duplicare la subnet riservata.

## Componenti e porte

| Servizio | Indirizzo dall'host | Indirizzo da VS Code | Persistenza |
| --- | --- | --- | --- |
| code-server | `http://<IP-server>:8443` | — | volumi `vscode_config`, `vscode_data` |
| Gitea | `http://<IP-server>:3001` | `http://gitea:3000` | `gitea-data/`, `gitea-config/` |
| Gitea SSH | `ssh://git@127.0.0.1:2225` | `ssh://git@gitea:2222` | `gitea-data/` |
| Gitea Actions Runner | non pubblicato | Gitea Actions | `gitea-runner-data/` |
| Dockge | `http://<IP-server>:5001` | `http://dockge:5001` | `dockge-data/`, `dockge-stacks/` |
| Vikunja | `http://<IP-server>:3456` | `http://vikunja:3456` | volumi `vikunja_db`, `vikunja_files` |
| Docker deployment DinD | app autorizzate dal proxy | usato da Dockge | `dockge-docker-data/` |
| PostgreSQL | `127.0.0.1:15432` | `postgres:5432` | `postgres-data/` |
| Redis | `127.0.0.1:16379` | `redis:6379` | `redis-data/` |
| MongoDB | `127.0.0.1:27018` | `mongodb:27017` | `mongodb-data/`, `mongodb-config/` |
| Docker DinD | non pubblicato | `tcp://docker:2375` | volume `vscode_docker_data` |

Le porte host indicate sono i valori predefiniti e possono essere cambiate nel
file `.env`.

## Avvio

Preparare il file delle variabili senza sovrascrivere un eventuale `.env`
esistente:

```bash
cd vscode-isolated
cp -n .env.example .env
chmod 600 .env
```

Modificare `.env` e sostituire **tutte** le password `change-me-*`. Le variabili
obbligatorie sono `VSCODE_PASSWORD`, `POSTGRES_PASSWORD`, `REDIS_PASSWORD` e
`MONGO_ROOT_PASSWORD`. Impostare inoltre `GITEA_ROOT_URL` e
`VIKUNJA_PUBLIC_URL` con l'IP o il dominio pubblico del server. Avviare quindi:

```bash
docker compose up -d
docker compose ps
```

Aprire `http://<IP-server>:8443`. La porta parla HTTP; per un'esposizione su
Internet occorre terminare TLS davanti a questo proxy e applicare regole di
accesso adeguate.

Per avviare soltanto l'IDE e Docker-in-Docker, senza Gitea e database:

```bash
docker compose up -d docker volume-init vscode reverse-proxy
```

Il runner Gitea è nel profilo opzionale `gitea-ci` e va avviato dopo aver
completato la prima configurazione di Gitea e inserito il token nel `.env`:

```bash
docker compose --profile gitea-ci up -d gitea-runner
```

## Usare il workspace condiviso

I file creati in `/workspace` da VS Code sono immediatamente visibili sull'host
in `vscode-isolated/workspace`. Per importare un progetto basta copiarlo in tale
directory dall'host:

```bash
mkdir -p ./workspace/project
cp -a /percorso/del/progetto/. ./workspace/project/
```

Non copiare `.env`, chiavi SSH, credential store o altri segreti non necessari.
Il container non può risalire dalla directory montata al suo genitore host:
`/workspace/..` è la root isolata del container.

## Estensioni

Le estensioni possono essere installate direttamente dal marketplace. Per una
procedura più controllata si può comunque scaricare e verificare un file `.vsix`
sull'host, quindi copiarlo e installarlo esplicitamente:

```bash
docker cp estensione-verificata.vsix isolated_vscode:/tmp/extension.vsix
docker exec isolated_vscode code-server \
  --install-extension /tmp/extension.vsix --force
```

Le estensioni vengono conservate nel volume `vscode_data`, mai nel profilo VS
Code dell'host. Un'estensione mantiene comunque accesso ai file presenti nel
workspace e, avendo accesso a Internet, può esfiltrarli: usare solo estensioni
fidate e non inserire segreti nel volume. L'isolamento impedisce invece la
lettura di file host che non siano stati importati esplicitamente.

Per GitHub Copilot, `COPILOT_HOME` è collocata nello stesso volume persistente
isolato, mentre `COPILOT_CACHE_HOME` usa il tmpfs. Questo permette a Copilot di
salvare stato e autenticazione senza rendere scrivibile tutta la home.

## Codex CLI

L'immagine derivata installa Codex CLI durante la build. Dal terminale integrato
di VS Code:

```bash
cd /workspace
codex
```

Al primo avvio completare l'accesso proposto da Codex. Configurazione,
autenticazione e sessioni sono salvate in `CODEX_HOME` dentro il volume
persistente `vscode_data`, non nel filesystem o nella home dell'host.

La cache npm è collocata nel `tmpfs` (dimensione configurabile con
`VSCODE_CACHE_SIZE`, 512 MB per impostazione predefinita), mentre i pacchetti globali npm sono
persistenti nel volume `vscode_data`. Sono quindi supportati sia `npm install`
nel progetto sia, quando necessario, l'aggiornamento del CLI:

```bash
npm install
npm install --global @openai/codex@latest
codex --version
```

Poiché code-server gira in un container, il callback standard su
`localhost:1455` appartiene al namespace di rete del container e non al browser
host. Usare quindi il login con codice dispositivo dal terminale integrato:

```bash
codex login --device-auth
```

Aprire nel browser host l'indirizzo mostrato e inserire il codice monouso. Se
l'opzione non è disponibile, abilitare prima il device-code login nelle
impostazioni di sicurezza dell'account ChatGPT o richiederne l'abilitazione
all'amministratore del workspace. Verificare infine con:

```bash
codex login status
codex
```

### Installazione manuale di un VSIX

Scaricare sull'host i pacchetti con estensione `.vsix` da fonti fidate,
verificarne provenienza e checksum e inserirli nella directory `vsix/`:

```bash
cp /percorso/*.vsix ./vsix/
./install-extension.sh
```

Lo script trova automaticamente tutti i file `vsix/*.vsix`, li copia
temporaneamente in `/tmp` e li installa come UID 1000. I file installati finiscono in
`/home/coder/.local/share/code-server/extensions`, incluso nel volume Docker
persistente `vscode_data`; rimangono quindi disponibili dopo `restart`, `down`
e successive ricreazioni. Vengono eliminati soltanto con `down --volumes`.

Per elencare le estensioni persistenti:

```bash
docker exec isolated_vscode code-server --list-extensions --show-versions
```

## Docker-in-Docker

L'immagine di VS Code include Docker CLI e Docker Compose. La variabile
`DOCKER_HOST=tcp://docker:2375` collega il terminale a un daemon annidato
dedicato: il socket `/var/run/docker.sock` dell'host non viene montato.

```bash
docker version
docker run --rm hello-world
cd /workspace/un-progetto
docker compose up -d
```

Immagini, container e volumi creati da questi comandi persistono nel volume
`vscode_docker_data`. Non compaiono nel `docker ps` eseguito sull'host e non
possono montare percorsi del filesystem host: un bind mount come
`./data:/data` viene risolto dal daemon DinD, non dall'host principale.

Il servizio `docker` usa `privileged: true`, necessario al daemon annidato, ma
non espone porte sull'host e non riceve né il socket Docker host né bind mount
host. Il container `vscode` continua a usare `runsc`, root filesystem read-only,
capability rimosse e `no-new-privileges`.

## Arresto e cancellazione

```bash
./stop.sh
```

L'arresto conserva sia la cartella workspace sia i volumi. Per cancellare
definitivamente configurazione ed estensioni isolate:

```bash
docker compose -f compose.yml down --volumes
```

Questa ultima operazione elimina i dati e va eseguita solo dopo avere esportato
ciò che serve.

## Gitea e database persistenti

Copiare `.env.example` in `.env`, mantenere l'attuale `VSCODE_PASSWORD` e
sostituire tutte le password `change-me-*` prima dell'avvio. I servizi sono
raggiungibili da VS Code con i nomi `gitea`, `postgres`, `redis` e `mongodb`.
Le interfacce web passano dal reverse proxy; database e SSH Gitea rimangono
limitati a `127.0.0.1`.

Esempi di connessione dal terminale o dalle applicazioni eseguite in VS Code:

```text
PostgreSQL: postgresql://app:<POSTGRES_PASSWORD>@postgres:5432/app
Redis:      redis://:<REDIS_PASSWORD>@redis:6379/0
MongoDB:    mongodb://root:<MONGO_ROOT_PASSWORD>@mongodb:27017/app?authSource=admin
Gitea:      http://gitea:3000
```

Da un programma eseguito direttamente sull'host usare invece `127.0.0.1` e le
porte `POSTGRES_HOST_PORT`, `REDIS_HOST_PORT` e `MONGO_HOST_PORT` definite nel
`.env`.

I dati persistono direttamente nelle seguenti directory dell'host:

- `gitea-data`, `gitea-config` e `gitea-runner-data`;
- `postgres-data`;
- `redis-data`;
- `mongodb-data` e `mongodb-config`.

### Variabili principali

Il file `.env.example` documenta tutte le opzioni. Oltre alle credenziali si
possono fissare le versioni delle immagini con `GITEA_VERSION`,
`POSTGRES_VERSION`, `REDIS_VERSION` e `MONGO_VERSION`. Per backup riproducibili
è preferibile usare versioni esplicite e conservarle durante il ripristino.

## Gitea SQLite e Gitea Actions Runner

Gitea usa esplicitamente SQLite in `gitea-data/data/gitea.db`; repository,
allegati e altri dati applicativi sono nello stesso `gitea-data/`, mentre
`gitea-config/` contiene la configurazione. Entrambe sono normali directory
dell'host e sopravvivono a restart, `down` e ricreazione dei container.

### Prima configurazione e amministratore

1. Avviare Gitea con `docker compose up -d gitea reverse-proxy`.
2. Attendere lo stato healthy con `docker compose ps gitea`.
3. Aprire `http://<IP-server>:3001`.
4. Nel wizard lasciare **SQLite3** e il percorso proposto, quindi compilare la
   sezione per creare il primo account amministratore.

Le impostazioni database sono già forzate dal Compose. Non impostare PostgreSQL
o MySQL nel wizard. Per clonare dall'host via SSH:

```bash
git clone ssh://git@127.0.0.1:2225/utente/progetto.git
```

### Registrare e avviare il runner

1. Entrare in Gitea come amministratore.
2. Aprire **Amministrazione sito → Actions → Runners** e creare/copiare un
   registration token globale. In alternativa, usare il token nella pagina
   **Impostazioni → Actions → Runners** di una specifica organizzazione o repo.
3. Inserire il valore, senza virgolette, in `GITEA_RUNNER_TOKEN` nel `.env`.
4. Avviare e controllare il runner:

```bash
docker compose --profile gitea-ci up -d gitea-runner
docker compose --profile gitea-ci logs -f gitea-runner
```

## Dockge con Docker-in-Docker isolato

Dockge è disponibile su `http://<IP-server>:5001`. Al primo accesso crea
l'account amministratore. La UI controlla esclusivamente il servizio
`dockge-docker` tramite `tcp://dockge-docker:2375`: il socket
`/var/run/docker.sock` dell'host non viene montato in nessuno dei due servizi.

Avvio e controllo:

```bash
docker compose up -d dockge-docker dockge reverse-proxy
docker compose ps dockge-docker dockge
docker compose logs -f dockge
```

Gli stack creati dalla UI sono salvati sull'host in `dockge-stacks/`. Il
percorso `/opt/stacks` è identico in Dockge e nel daemon remoto, requisito
necessario perché bind mount e percorsi relativi siano risolti correttamente.
Configurazione e account Dockge persistono in `dockge-data/`; immagini,
container e volumi delle applicazioni persistono in `dockge-docker-data/`.

### Eseguire l'immagine di vite-login-app

È già predisposto lo stack `vite-login-app`, basato su:

```yaml
services:
  app:
    image: gitea:3000/dev/test:latest
    pull_policy: always
    ports:
      - "18081:8080"
```

Se il package è privato, prima del deploy autenticare il client Dockge nel
registry usando un personal access token Gitea con lettura dei package:

```bash
docker exec -it isolated_dockge docker login gitea:3000
```

Inserire username Gitea e token, non la password dell'account. Per package
pubblici il login non è necessario. Le eventuali credenziali
rimangono nella directory isolata `dockge-docker-config/`. Aprire quindi Dockge,
selezionare **Scan Stacks Folder**, scegliere `vite-login-app` e premere
**Start** o **Update**. L'app sarà raggiungibile su:

```text
http://<IP-server>:18081
```

Il container annidato non pubblica porte direttamente sull'host. Per aggiungere
un'altra app, autorizzare esplicitamente la sua porta nel servizio
`reverse-proxy` e aggiungere il relativo blocco `server` in
`reverse-proxy/nginx.conf`.
Per aggiornare `latest`, dalla UI usare **Update**; `pull_policy: always` forza
il pull prima della ricreazione.

Il file di registrazione del runner rimane in `gitea-runner-data/`. Il volume
`gitea_runner_docker_data` conserva immagini e cache del daemon DinD; può essere
ricreato senza perdere repository, configurazione Gitea o registrazione.

Esempio `.gitea/workflows/test.yml`:

```yaml
name: test
on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "Pipeline eseguita dal runner Gitea isolato"
```

Il runner è `privileged` perché contiene il proprio Docker-in-Docker, ma non
riceve il socket Docker dell'host. I workflow vanno comunque considerati codice
privilegiato rispetto ai dati e alle cache appartenenti a quel runner.

### Pubblicare immagini nel Container Registry

Il daemon DinD del runner accetta esclusivamente il registry HTTP locale
`gitea:3000`; i job ricevono una risoluzione statica di quel nome verso il
container Gitea. Per questo `GITEA_ROOT_URL` deve restare
`http://gitea:3000/`: è anche l'indirizzo usato nel challenge di autenticazione
del registry.

In ogni repository che deve pubblicare immagini creare un access token Gitea
con permesso di scrittura sui package, quindi aggiungere in
**Settings → Actions → Secrets**:

- `REGISTRY_USER`, contenente il nome utente Gitea;
- `REGISTRY_TOKEN`, contenente il token.

Il progetto `workspace/vite-login-app` include un esempio completo in
`.gitea/workflows/container.yml`. Dopo una modifica alla configurazione del
runner, applicarla con:

```bash
docker compose --profile gitea-ci up -d --force-recreate gitea gitea-runner
docker compose --profile gitea-ci logs -f gitea-runner
```

### Backup cold consistente

Eseguire dalla directory `vscode-isolated`. Il fermo dei servizi evita
copie incoerenti mentre i database stanno scrivendo:

```bash
docker compose --profile gitea-ci stop \
  gitea gitea-runner dockge dockge-docker postgres redis mongodb
tar --xattrs --acls -czf ../vscode-services-backup.tgz \
  .env gitea-data gitea-config gitea-runner-data \
  dockge-data dockge-stacks dockge-docker-config dockge-docker-data \
  postgres-data redis-data mongodb-data mongodb-config
docker compose --profile gitea-ci start \
  postgres redis mongodb gitea gitea-runner dockge-docker dockge
```

Proteggere il backup perché contiene password, repository e dati applicativi.

### Ripristino cold

Su una directory vuota contenente questi file Compose, arrestare i servizi,
estrarre il backup preservando proprietari e permessi, quindi ricrearli:

```bash
docker compose --profile gitea-ci down
sudo tar --xattrs --acls -xzf ../vscode-services-backup.tgz -C .
docker compose --profile gitea-ci up -d
```

Dopo il ripristino verificare tutti gli healthcheck:

```bash
docker compose --profile gitea-ci ps
docker compose logs --tail=100 gitea dockge-docker dockge postgres redis mongodb
```

Non usare `docker compose down --volumes` se si vuole conservare anche il daemon
DinD: quell'opzione elimina `vscode_docker_data`, oltre alla configurazione e
alle estensioni dell'IDE. Le directory bind mount dei database e di Gitea non
vengono eliminate da `down --volumes`, ma vanno comunque incluse nei backup.
