# AGENTS.md — homebrew-tap

**homebrew-tap** (`github.com/Allan-Nava/homebrew-tap`): tap Homebrew dei progetti Allan-Nava. Contiene **solo** cask (nessun codice applicativo): `Casks/checkfleet.rb` (CLI [checkfleet](https://github.com/Allan-Nava/checkfleet)) e `Casks/checkfleet-desktop.rb` (app Wails). Più gli script/workflow che li generano e validano.

Questo file definisce le regole operative per gli agent (Copilot, Claude, altri tool AI) quando lavorano in questo repository.

## Regole di lavoro (SEMPRE)

- **MAI editare a mano i file in `Casks/`**: sono generati. `checkfleet.rb` lo scrive **GoReleaser** dal repo upstream a ogni tag `v*` → un cambio si fa in `.goreleaser.yaml` (`homebrew_casks`) e si rilascia. `checkfleet-desktop.rb` lo scrive **`scripts/render-desktop-cask.sh`** (GoReleaser non builda l'app desktop) → un cambio si fa nel template dentro quello script e si rigenera.
- **Nessun bump di versione manuale**: `version` e gli `sha256` vengono calcolati sugli asset reali della release. Riscriverli a mano = install rotta con checksum mismatch.
- **MAI `git push`**: lo fa sempre l'utente. MAI `Co-Authored-By` nei commit.
- **Niente CHANGELOG/tag qui**: il versioning vive nel repo del progetto. La history è quasi tutta bot (`Brew cask update for <tool> version vX.Y.Z`): non inquinarla.
- **Gate prima di chiudere** (se si tocca un cask, uno script o un workflow): `brew style` + `brew audit --cask --online` verdi e il cask che si carica (`brew info --cask`). I cask **devono stare dentro un tap**: usare `scripts/ci-place-tap.sh` e poi lavorare per token, non per path.
- **Todo → `BACKLOG.md`** (id stabili `HT-n`), niente TODO sparsi nei file. Gli item che si chiudono upstream lo dicono esplicitamente.
- **Niente segreti** nel repo: `HOMEBREW_TAP_GITHUB_TOKEN` è un secret della CI upstream, non compare mai qui.

## Comandi

```bash
scripts/ci-place-tap.sh                  # copia il checkout in Library/Taps come allan-nava/tap
brew style --except-cops Cask/Desc,Layout/EmptyLinesAroundBlockBody allan-nava/tap
brew info --cask allan-nava/tap/checkfleet
brew audit --cask --online allan-nava/tap/checkfleet
brew install --cask allan-nava/tap/checkfleet     # HOMEBREW_NO_REQUIRE_TAP_TRUST=1 in headless
scripts/render-desktop-cask.sh [vX.Y.Z]  # rigenera il cask desktop dalla release
```

## Trappole note

- **I cask fuori da un tap sono rifiutati**: `brew info --cask ./Casks/x.rb` → "Homebrew requires casks to be in a tap". Ogni validazione passa da `scripts/ci-place-tap.sh`.
- **`brew style` ignora un `.rubocop.yml` del tap** (forza `--config Library/.rubocop.yml`): le esclusioni vivono in `--except-cops` nei workflow, con puntatore a `HT-2`.
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
