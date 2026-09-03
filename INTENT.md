# INTENT.md — homebrew-tap

**Perché questo repository esiste**, cosa si impegna a garantire e cosa
*deliberatamente* non fa. È il documento di intento: sopravvive alle singole
feature, e serve a misurare una proposta prima che qualcuno la scriva. Quando un
cambiamento è plausibile ma non sta in questo file, vince questo file.

| File | Domanda a cui risponde |
|---|---|
| **`INTENT.md`** (questo) | **Perché** il tap esiste, cosa garantisce, cosa è fuori scope |
| [`README.md`](README.md) | **Cosa** c'è dentro — install/upgrade/uninstall, i cask, le piattaforme. L'unica doc user-facing (in inglese, come i suoi lettori) |
| [`AGENTS.md`](AGENTS.md) · [`CLAUDE.md`](CLAUDE.md) | **Come** si lavora qui — regole operative e trappole verificate, per persone e per agent AI |
| [`BACKLOG.md`](BACKLOG.md) | **Cosa manca** — sorgente unica dei todo (`HT-n`), da cui si generano le issue |
| I repo dei progetti | **Quando** e **con che contenuto** — versione, release e template del cask stanno lì, non qui. Per questo il tap non ha tag né CHANGELOG |

---

## 1. In una riga

Far sì che `brew install --cask <progetto>` funzioni per ogni progetto
Allan-Nava, **senza che nessuno scriva o aggiorni un cask a mano.**

## 2. Il problema che risolve

I progetti pubblicano binari già compilati. Senza un tap, installarli significa
"scarica il tarball giusto per la tua architettura, scompattalo, mettilo nel
PATH, togli la quarantine, e per la prossima versione arrangiati". Un tap
trasforma tutto questo in una riga, e `brew upgrade` nel resto.

Ma un tap introduce il problema vero: **è un secondo posto in cui vive una
versione.** E un secondo posto sbaglia in due modi, entrambi peggiori di un
bug normale perché arrivano *dopo* che la release è pubblica:

- **Un checksum che non torna.** L'utente vede `SHA256 mismatch` e non ha
  nessuno strumento per capire di chi è la colpa: la release c'è, il tap c'è,
  l'install no.
- **Un tap che resta indietro, in silenzio.** I PAT fine-grained scadono per
  forza; quando scadono, la release upstream pubblica archivi e immagine e poi
  fallisce **solo** sul push qui. Da quel momento il tap serve una versione
  vecchia e **tutto resta verde** — il cask si carica, l'audit passa, la CI è
  contenta — perché `livecheck { skip }` è voluto e nessuno confronta con
  upstream.

C'è poi un fatto strutturale che decide quasi tutte le regole di questo repo:
**questo repository è scritto quasi interamente da macchine.** 159 dei 176
commit sono `Brew cask update for …`; per autore, 146 goreleaserbot e 12
github-actions[bot] contro 18 umani. Qualunque abitudine del tipo "lo sistemo
qui a mano" viene sovrascritta dalla release successiva, senza avvisare.

## 3. Obiettivi, in ordine di priorità

1. **Un cask non lo scrive nessuno a mano.** Lo genera GoReleaser dal repo del
   progetto, o — per ciò che GoReleaser non builda, cioè l'app desktop Wails —
   `scripts/render-desktop-cask.sh` da qui. Il marker `DO NOT EDIT` in testa al
   file è il confine operativo, non un commento: ci si appoggiano i bucket di
   `brew style` e il sincronizzatore.
2. **I checksum vengono dagli asset veri della release.** Sempre ricalcolati
   scaricando il file, mai copiati, mai scritti a mano — nemmeno dal nostro
   sincronizzatore, che infatti scarica i quattro tarball prima di toccare una
   riga.
3. **Un tap indietro deve diventare visibile, e ripararsi.**
   `scripts/sync-cask-versions.sh` (workflow `cask-sync.yml`, ogni 6h) confronta
   ogni cask generato con `releases/latest` del progetto, risincronizza dagli
   asset e tiene aperta una issue — perché il sync cura il sintomo e la causa
   sta nel token upstream.
4. **Un cask rotto non deve arrivare all'utente.** `cask-ci.yml` fa style,
   caricamento su ogni OS/arch, install reale su due architetture con la
   versione del binario confrontata con quella del cask, e `audit --online` che
   riscarica gli asset.
5. **Il fix va dove sta la causa.** Il contenuto di un cask generato si corregge
   nel `.goreleaser.yaml` del progetto e arriva con la release successiva. Qui
   si aggiusta solo ciò che è nostro: script, workflow, template del cask
   desktop.
6. **La documentazione segue il tap da sola.** Gli elenchi dei cask nel README
   sono generati da `Casks/*.rb` fra marker: il tap acquisisce progetti senza
   intervento umano, quindi un elenco scritto a mano invecchierebbe per
   costruzione — è già successo con `abrsim`.
7. **Zero segreti qui.** I token con cui si scrive nel tap sono secret nei repo
   dei progetti. In questo repo non deve comparirne nessuno.

## 4. Non-obiettivi (espliciti)

Nessuno di questi è un buco da riempire: ognuno è una decisione.

- **Non è un posto dove si sviluppa.** Zero codice applicativo, zero build. Se
  una modifica richiede di compilare qualcosa, è nel repo sbagliato.
- **Nessuna formula, solo cask** (HT-12). Un cask i cui artifact sono solo
  `binary` **non** è macOS-only — `Cask::Artifact::Binary` non è in
  `MACOS_ONLY_ARTIFACTS` — quindi i CLI si installano già su Linuxbrew e i rami
  `on_linux` sono reali. Una formula sarebbe solo un secondo posto dove
  sbagliare la versione.
- **Nessun `livecheck` reale** (HT-15). La versione la spinge la release. Un
  livecheck sarebbe una seconda fonte di verità che può divergere; il confronto
  con upstream lo fa un job esplicito, non il DSL del cask.
- **Nessun bump manuale di `version`/`sha256`.** A mano significa `SHA256
  mismatch` in mano a un utente.
- **Nessun tag e nessun CHANGELOG in questo repo.** Versioning e note di
  rilascio vivono nel repo del progetto; qui la history è il registro di cosa è
  arrivato, e va tenuta pulita dai commit rumorosi.
- **Non è homebrew-core né homebrew-cask.** Nessun autobump di BrewTestBot,
  nessun processo di review di terzi: è un tap di terze parti, e Homebrew 6+ lo
  dice all'utente chiedendo il *trust*.
- **Non ospita binari.** Nel repo ci sono url e checksum, non asset. Gli
  artefatti stanno nelle release dei progetti, che restano l'unica sorgente.
- **Non si "aggira" un problema upstream toccando `Casks/`.** Quel file viene
  riscritto alla release successiva: la modifica sparirebbe, e nel frattempo
  avrebbe fatto sembrare risolto un problema aperto.
- **Mai `brew style --fix`, e mai `brew style` sull'intero tap.** Su un tap
  Homebrew passa shellcheck+shfmt anche sugli script, e quel formatter **tronca
  l'heredoc** di `render-desktop-cask.sh` (verificato: il cask reso perde tutto
  ciò che segue `postflight do`).
- **`git push` non lo fa un agent.** Lo fa una persona, sempre.

## 5. Principi — gli invarianti, con il perché

| Principio | Perché |
|---|---|
| **Il marker `DO NOT EDIT` è il confine, non un commento** | È l'unico modo automatico di dire "questo file lo possiamo correggere" da "questo torna come prima alla prossima release". Ci si appoggiano i due bucket di `brew style` e il sincronizzatore, e un cask nuovo finisce nel bucket giusto senza che nessuno aggiorni un elenco. |
| **I cask si validano dentro un tap** | `brew info --cask ./Casks/x.rb` viene rifiutato ("Homebrew requires casks to be in a tap"), quindi ogni verifica passa da `scripts/ci-place-tap.sh` e lavora per token. |
| **Le esclusioni di `brew style` valgono solo per i cask generati** (HT-22) | Un'offense nel template *nostro* è un bug da correggere; una nel template di GoReleaser non è correggibile in nessuno dei nostri repo. Mescolarle significa concedere al nostro codice lo sconto che serve al loro. |
| **Ogni cop escluso ha un item che lo riporta a zero** | Altrimenti l'esclusione diventa permanente per inerzia e `brew style` smette di dire qualcosa. `Cask/Desc` → HT-2; `Style/NumericPredicate` era HT-21, atterrato e rimosso. |
| **Il `postflight` anti-quarantine è voluto** | Niente firma né notarizzazione. Senza quello un CLI non firmato non dà il dialogo "sviluppatore non identificato" che riceve una GUI: muore su SIGKILL, exit 137, **senza output** — e chi lo segnala segnalerà il bug sbagliato. |
| **`livecheck { skip }` è voluto, il confronto con upstream è un job** | La versione ha una sola sorgente (la release). Il drift si scopre con un controllo esplicito che può aprire una issue, non con un DSL che indovina. |
| **`brew audit --online` vuole un token** (HT-24) | Senza token sono 60 richieste/ora **per IP**, e sui runner hosted l'IP è condiviso: l'audit muore con `exception while auditing`, che Homebrew conta come errore. Job rosso, e issue "Tap rotto" per un motivo che col tap non c'entra. |
| **Il drift è un silenzio, quindi va cercato attivamente** (HT-26) | Nessun gate esistente può accorgersene: sono tutti verdi per costruzione quando il tap è indietro. L'unico segnale è il confronto con upstream. |
| **Gli elenchi del README sono generati** (HT-27) | Il tap acquisisce progetti da sé; un elenco a mano di una cosa che cresce da sola invecchia per costruzione. La prosa attorno resta a mano: è la parte che vale. |
| **Le issue si generano dal backlog, non a mano** | Due piani divergono, e quello che conta è quello che nessuno ha aperto. `BACKLOG.md` è la sorgente; spuntare un item chiude la sua issue. |
| **Una CI perennemente rossa insegna solo a ignorare la CI** (HT-19) | Per questo il workflow template è stato rimosso, le esclusioni sono motivate una per una, e un README stantio è un `::warning::` e non un job rosso: su main il sync lo ripara in un minuto, e un rosso transitorio aprirebbe "Tap rotto" per un ritardo di documentazione. |
| **Un solo writer per volta sul tap** | `cask-sync.yml` e `desktop-cask.yml` condividono il gruppo di concurrency `tap-write` e hanno i cron sfasati, perché due job che committano lo stesso file si rompono a vicenda. |
| **Il repo va tenuto allineato a `origin/main`** | GoReleaser pusha qui **durante** la release di un progetto: un commit locale divergente non rompe questo repo, rompe quella release a metà. |
| **`cancelled` non è un fallimento del tap** | Con `cancel-in-progress` un push che segue un altro cancella il precedente. Trattarlo come rosso apre la issue a sproposito. |

## 6. Confini — cosa vive dove

```
  REPO DEI PROGETTI                  QUESTO TAP                      UTENTE
  (dove si sviluppa)              (dove si distribuisce)

  checkfleet     ┐
  segcheck       │   tag v*        Casks/<progetto>.rb              brew tap
  ladder-bench   ├──────────────▶  version · url · sha256 · desc       │
  abrsim         ┘   GoReleaser    postflight  — DO NOT EDIT           │
                                                                       ▼
  checkfleet         asset nella   Casks/checkfleet-desktop.rb     brew install
  (desktop.yml)  ───────────────▶  reso da                             --cask
                     release       render-desktop-cask.sh              │
                                                                       ▼
                                   VALIDAZIONE                     binario nel
                                     brew style (due bucket)       PATH, o .app
                                     load su ogni OS/arch
                                     install reale su 2 arch
                                     audit --online

                                   SORVEGLIANZA
                                     drift ↔ releases/latest
                                     fix upstream atterrati?
                                     README ↔ Casks/
```

Regola pratica: **il contenuto di un cask si corregge dove viene generato.**
Versione, `desc`, `caveats`, completions, dipendenze, postflight → nel
`.goreleaser.yaml` del progetto. Template del cask desktop, validazione,
sorveglianza, documentazione del tap → qui.

## 7. Come entra un cambiamento

Nell'ordine — l'ordine è il punto:

1. **Un `HT-n` in [`BACKLOG.md`](BACKLOG.md)**, nella sezione giusta (la sezione
   è la milestone). La issue la crea `backlog-sync.sh`: non aprirla a mano.
2. **Si chiude qui o upstream?** Se il cambiamento riguarda il *contenuto* di un
   cask generato, si chiude upstream e l'item lo dichiara. Toccare `Casks/`
   sarebbe una modifica che sparisce alla release successiva.
3. **Se è nostro**, si modifica lo script, il template o il workflow — non il
   file generato — e si **rigenera davvero**, leggendo il diff.
4. **Gate prima di chiudere**: `scripts/ci-place-tap.sh`, `brew style` nei due
   bucket, `brew info --cask` su ogni cask, `brew audit --cask --online` con
   `HOMEBREW_GITHUB_API_TOKEN`. Per gli script `shellcheck`, per i workflow
   `scripts/check-workflows.rb` (un `needs:` verso un job cancellato non dà un
   errore leggibile: rende il workflow invalido e il run fallisce senza job né
   log).
5. **Allineare tutto nello stesso commit**: elenchi del README rigenerati,
   `CLAUDE.md`/`AGENTS.md` se cambia una regola o una trappola, item spuntato.
6. **Niente `git push`, niente `Co-Authored-By`.**

## 8. Come si vede che funziona

- **Un progetto nuovo entra nel tap senza che nessuno tocchi questo repo** — e
  ora anche nel README: `abrsim` è arrivata con due commit del bot, e la sola
  cosa che era rimasta indietro (la documentazione) oggi si rigenera da sé.
- **Un utente non incontra mai un `SHA256 mismatch`**, perché nessun checksum in
  questo repo è stato scritto o copiato a mano.
- **Un tap indietro salta fuori entro sei ore** con una issue che dice quale
  release non è arrivata, invece di restare invisibile fino a quando qualcuno
  installa e ottiene la versione di due mesi prima.
- **La CI è verde**, quindi quando diventa rossa qualcuno la guarda davvero.
- **Il lavoro umano qui resta raro**: il 90% dei commit è del bot, ed è la misura
  giusta. Se questo repo comincia a richiedere commit a mano frequenti, qualcosa
  è tornato manuale e va rimesso a posto.

## 9. Per chi è

Chi installa questi strumenti su macOS o Linux e vuole una riga invece di un
tarball, e chi li aggiorna con `brew upgrade` senza sapere né volere sapere come
sono buildati.

E gli **agent AI** che lavorano in questo repository, per i quali un intento
scritto è l'unico modo di distinguere "manca" da "deliberatamente assente" — la
differenza fra correggere un cask e riscrivere un file che tornerà come prima
alla release successiva. Le regole operative stanno in [`AGENTS.md`](AGENTS.md) e
[`CLAUDE.md`](CLAUDE.md).

## 10. Manutenzione di questo file

`INTENT.md` cambia raramente: si aggiorna quando cambia lo **scopo**, non quando
cambiano i fatti. Si tocca se si aggiunge o si abbandona un obiettivo, se un
non-obiettivo smette di esserlo (una formula per Linux, un livecheck vero, dei
binari ospitati qui), se si sposta un confine con i repo dei progetti, o se un
principio viene davvero rivisto. Tutto ciò che è factuale — quali cask ci sono,
i comandi, le versioni, le trappole — vive in [`README.md`](README.md),
[`CLAUDE.md`](CLAUDE.md) e [`BACKLOG.md`](BACKLOG.md), che sono le sorgenti
vive.

Ultima revisione: 2026-09-03.
