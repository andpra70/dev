# VS Code isolato con gVisor

Questo esempio esegue `code-server` con `runsc` e lo espone soltanto su
`127.0.0.1:8443`. Monta dall'host esclusivamente la sottocartella dedicata
`vscode-isolated/workspace`; configurazione ed estensioni vivono in volumi
Docker separati e non modificano `~/.vscode` o `~/.config/Code` dell'host.
Il container IDE usa la rete bridge predefinita e DNS esterni espliciti per
scaricare estensioni e consultare Internet, senza che questo gli conceda accesso
al filesystem host. La porta del servizio resta pubblicata esclusivamente
sull'interfaccia loopback dell'host.

## Avvio

```bash
cd vscode-isolated
export VSCODE_PASSWORD='usare-una-password-lunga-e-casuale'
./start.sh
```

Aprire `http://127.0.0.1:8443`. Il certificato TLS e l'autenticazione di rete
andrebbero terminati in un reverse proxy se si vuole esporre il servizio oltre
localhost.

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

La cache npm è collocata nel `tmpfs`, mentre i pacchetti globali npm sono
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

## GitLab e database persistenti

Copiare `.env.example` in `.env`, mantenere l'attuale `VSCODE_PASSWORD` e
sostituire tutte le password `change-me-*` prima dell'avvio. I servizi sono
raggiungibili da VS Code con i nomi `gitlab`, `postgres`, `redis` e `mongodb`.
Le porte pubblicate sull'host sono limitate a `127.0.0.1`.

I dati persistono direttamente nelle seguenti directory dell'host:

- `gitlab-data/config`, `gitlab-data/logs`, `gitlab-data/data`;
- `postgres-data`;
- `redis-data`;
- `mongodb-data` e `mongodb-config`.

GitLab può richiedere diversi minuti al primo avvio. Per controllare lo stato:

```bash
docker compose ps
docker compose logs -f gitlab
```

### Backup cold consistente

Eseguire dalla directory `vscode-isolated`. Il fermo dei quattro servizi evita
copie incoerenti mentre i database stanno scrivendo:

```bash
docker compose stop gitlab postgres redis mongodb
tar --xattrs --acls -czf ../vscode-services-backup.tgz \
  .env gitlab-data postgres-data redis-data mongodb-data mongodb-config
docker compose start postgres redis mongodb gitlab
```

Proteggere il backup perché contiene password, repository e dati applicativi.
In particolare non perdere `gitlab-data/config/gitlab-secrets.json`.

### Ripristino cold

Su una directory vuota contenente questi file Compose, arrestare i servizi,
estrarre il backup preservando proprietari e permessi, quindi ricrearli:

```bash
docker compose down
sudo tar --xattrs --acls -xzf ../vscode-services-backup.tgz -C .
docker compose up -d
```
