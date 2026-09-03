# AGENTS.md — homebrew-tap

**homebrew-tap** (`github.com/Allan-Nava/homebrew-tap`): tap Homebrew dei progetti Allan-Nava. Contiene **solo** cask (nessun codice applicativo): `Casks/checkfleet.rb` (CLI [checkfleet](https://github.com/Allan-Nava/checkfleet)), `Casks/checkfleet-desktop.rb` (app Wails), `Casks/segcheck.rb` (CLI [segcheck](https://github.com/Allan-Nava/segcheck)), `Casks/ladder-bench.rb` (CLI [ladder-bench](https://github.com/Allan-Nava/ladder-bench), che dipende da `ffmpeg`) e `Casks/abrsim.rb` (CLI [abrsim](https://github.com/Allan-Nava/abrsim)). Più gli script/workflow che li generano e validano.

Questo file definisce le regole operative per gli agent (Copilot, Claude, altri tool AI) quando lavorano in questo repository.

## Regole di lavoro (SEMPRE)

- **MAI editare a mano i file in `Casks/`**: sono generati. `checkfleet.rb`, `segcheck.rb`, `ladder-bench.rb` e `abrsim.rb` li scrive **GoReleaser** dal repo del progetto a ogni tag `v*` → un cambio si fa nel `.goreleaser.yaml` di quel progetto (`homebrew_casks`) e si rilascia. `checkfleet-desktop.rb` lo scrive **`scripts/render-desktop-cask.sh`** (GoReleaser non builda l'app desktop) → un cambio si fa nel template dentro quello script e si rigenera.
- **Nessun bump di versione manuale**: `version` e gli `sha256` vengono calcolati sugli asset reali della release. Riscriverli a mano = install rotta con checksum mismatch.
- **MAI `git push`**: lo fa sempre l'utente. MAI `Co-Authored-By` nei commit.
- **Niente CHANGELOG/tag qui**: il versioning vive nel repo del progetto. La history è quasi tutta bot (`Brew cask update for <tool> version vX.Y.Z`): non inquinarla.
- **Gate prima di chiudere** (se si tocca un cask, uno script o un workflow): `brew style` + `brew audit --cask --online` verdi e il cask che si carica (`brew info --cask`). I cask **devono stare dentro un tap**: usare `scripts/ci-place-tap.sh` e poi lavorare per token, non per path.
- **Todo → `BACKLOG.md`** (id stabili `HT-n`), niente TODO sparsi nei file. Gli item che si chiudono upstream lo dicono esplicitamente.
- **Le issue sono generate dal backlog**: `scripts/backlog-sync.sh` (workflow `backlog-sync.yml`) crea/chiude/riapre una issue per `HT-n`. **Mai aprire o chiudere issue a mano** — si spunta l'item nel BACKLOG. Le altre due issue automatiche (`Fix upstream arrivato: HT-n`, `Tap rotto: la CI dei cask è rossa`) le gestisce `scripts/gh-issue.sh`: idempotenti per titolo, non commentano a ogni run.
- **Niente segreti** nel repo: `HOMEBREW_TAP_GITHUB_TOKEN` è un secret della CI upstream, non compare mai qui.

## Comandi

```bash
scripts/ci-place-tap.sh                  # copia il checkout in Library/Taps come allan-nava/tap
# style: due bucket, sui FILE (mai sul tap, mai --fix). Generati da GoReleaser:
brew style --except-cops Cask/Desc,Style/NumericPredicate,Layout/EmptyLinesAroundBlockBody,Cask/StanzaOrder,Cask/StanzaGrouping,Layout/FirstArrayElementIndentation \
  "$(brew --repository)"/Library/Taps/allan-nava/homebrew-tap/Casks/{checkfleet,segcheck,ladder-bench,abrsim}.rb
# Reso da noi, senza esclusioni:
brew style "$(brew --repository)"/Library/Taps/allan-nava/homebrew-tap/Casks/checkfleet-desktop.rb
brew info --cask allan-nava/tap/checkfleet
brew audit --cask --online allan-nava/tap/checkfleet
brew install --cask allan-nava/tap/checkfleet     # HOMEBREW_NO_REQUIRE_TAP_TRUST=1 in headless
scripts/render-desktop-cask.sh [vX.Y.Z]  # rigenera il cask desktop dalla release
shellcheck scripts/*.sh                  # gli script devono restare verdi
scripts/check-workflows.rb               # needs coerenti fra i job dei workflow
scripts/backlog-sync.sh --dry-run        # cosa farebbe il sync BACKLOG.md → issue
scripts/check-upstream-fixes.sh          # TSV: quali fix upstream sono atterrati
DRY_RUN=1 scripts/gh-issue.sh ensure-open "<titolo>" body.md <label>
```

## Trappole note

- **Un cask indietro non fa diventare rosso niente**: se il PAT del tap scade upstream, la release pubblica tutto tranne il push qui e il tap serve una versione vecchia con tutti i gate verdi. Il detector è `scripts/sync-cask-versions.sh` (`--check` diagnostica, `--apply` risincronizza dagli asset veri), girato ogni 6h da `cask-sync.yml`. La causa però è il token nel repo del progetto (HT-26).
- **`brew audit --online` vuole un token GitHub**: senza, sono 60 richieste/ora per IP (condiviso, sui runner) e l'audit fallisce con `exception while auditing <cask>` — job rosso per un problema che non è del tap. In CI c'è già nell'`env` dei workflow; in locale `HOMEBREW_GITHUB_API_TOKEN="$(gh auth token)"` (HT-24).
- **I cask fuori da un tap sono rifiutati**: `brew info --cask ./Casks/x.rb` → "Homebrew requires casks to be in a tap". Ogni validazione passa da `scripts/ci-place-tap.sh`.
- **`brew style` ignora un `.rubocop.yml` del tap** (usa il suo, `Library/.rubocop.yml`; `--config` dalla CLI non esiste: `Error: invalid option`): le esclusioni vivono in `--except-cops` nei workflow. Valgono **solo per i cask generati da GoReleaser** — il job `lint` divide i file sul marker `DO NOT EDIT` e stila senza esclusioni quelli resi da noi (HT-22). Ogni cop escluso per colpa nostra ha un item che lo riporta a zero: `Cask/Desc` → HT-2, `Style/NumericPredicate` → HT-21.
- **MAI `brew style --fix`, e mai `brew style` su tutto il tap**: su un tap Homebrew passa anche shellcheck+shfmt sugli script, e il formatter **tronca l'heredoc** di `render-desktop-cask.sh` (verificato: il cask reso perde tutto dopo `postflight do`). Si stilano solo i file `Casks/*.rb`; gli script hanno un job shellcheck a parte.
- **Il `postflight` con `xattr -dr com.apple.quarantine` è VOLUTO** in entrambi i cask: i binari non sono firmati/notarizzati. Non rimuoverlo; per il CLI si cambia negli `hooks.post.install` upstream.
- **`livecheck { skip }` è voluto**: la versione la spinge la release, non il livecheck.
- **`depends_on` con versione macOS vecchia rompe il caricamento**: nel cask desktop serve il `depends_on :macos` nudo (il bundle dichiara 10.13, sotto il minimo supportato da Homebrew).
- **Cask, non formula**: nessuna compilazione da sorgente. Un cask con solo `binary` **non** è macOS-only: `checkfleet` si installa anche su Linuxbrew, il ramo `on_linux` è reale.
- Nome repo `homebrew-tap` → si usa come `Allan-Nava/tap` (Homebrew taglia il prefisso `homebrew-`).
- **Race sui push**: GoReleaser pusha qui durante la release upstream. Un commit locale divergente fa fallire quella release; il workflow del cask desktop si difende con `pull --rebase` + retry e `concurrency: tap-write`.

## Puntatori

- Backlog: `BACKLOG.md` (`HT-n`) · CI: `.github/workflows/cask-ci.yml`, `.github/workflows/desktop-cask.yml`
- Progetto upstream: `~/projects/github.com/checkfleet` (`.goreleaser.yaml` → `homebrew_casks`, `.github/workflows/desktop.yml`, `brew-test.yml`)
- README utente: `README.md`
