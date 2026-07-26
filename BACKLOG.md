# Backlog — homebrew-tap

Sorgente unica dei todo di questo repo. Id stabili `HT-n`; spuntare, non cancellare.

Attenzione al confine: qui si distribuisce, non si sviluppa. Diversi item **si chiudono con un commit upstream** in [`checkfleet`](https://github.com/Allan-Nava/checkfleet) (`.goreleaser.yaml` → `homebrew_casks`), non toccando `Casks/` — quel file è generato e viene riscritto a ogni release. Ogni item dice dove va fatto il lavoro.

## Automazione del tap

- [x] **HT-3 — CI del tap**: `.github/workflows/cask-ci.yml` — `brew style` + caricamento di ogni cask, shellcheck degli script, install reale su `macos-14`/`macos-13` (versione del binario == versione del cask, quarantine rimossa, smoke `check tcp`), install del bundle desktop, `brew audit --cask --online`. Su push/PR, ogni lunedì e a mano. Due vincoli scoperti provando: i cask vanno validati **dentro un tap** (Homebrew rifiuta `--cask ./Casks/x.rb`) → `scripts/ci-place-tap.sh`; e `brew style` va dato sui **file** `Casks/*.rb`, non sul tap, perché su un tap gira anche shfmt sugli script e `--fix` tronca l'heredoc del renderer. _(qui)_
- [x] **HT-4 — Cask `checkfleet-desktop`**: l'app Wails era pubblicata nelle release ma non installabile da brew. `scripts/render-desktop-cask.sh` risolve l'asset `checkfleet-desktop_v*_darwin_universal.zip`, ne calcola lo sha256, verifica che `checkfleet.app` sia alla radice dello zip e rende il cask (`app`, `depends_on :macos`, postflight anti-quarantine, `zap` su Caches/Preferences/WebKit/SavedState di `com.wails.checkfleet`); `.github/workflows/desktop-cask.yml` lo aggiorna (dispatch + cron 6h + manuale), valida con `brew style`/`brew info` e committa solo se cambia, con rebase in caso di gara col push di GoReleaser. _(qui; verificato con style/info/`audit --online` su v0.125.0)_
- [ ] **HT-5 — Trigger immediato del cask desktop** (**upstream**): step finale in `desktop.yml` che fa `repository_dispatch` di tipo `checkfleet-desktop-release` su questo repo con `client_payload.tag`. Serve un PAT con `contents:write` sul tap (riusare `HOMEBREW_TAP_GITHUB_TOKEN`). Senza questo il cask desktop si aggiorna col cron, quindi con qualche ora di ritardo.
- [ ] **HT-10 — Notifica su tap rotto**: oggi un fallimento della CI settimanale si vede solo in Actions. Valutare un output verso l'esterno (issue automatica sul tap, o `report-issues` di checkfleet). Da fare solo se il rumore vale il segnale.

## Contenuto dei cask (lavoro upstream)

- [ ] **HT-1 — Completions shell nel cask** (**upstream**): la CLI ha `checkfleet completion bash|zsh|fish` ma il cask installa solo il binario, quindi da brew nessuno le ha. In `.goreleaser.yaml` → `homebrew_casks`:
  ```yaml
  generate_completions_from_executable:
    executable: checkfleet
    args: ["completion"]
    shells: [bash, zsh, fish]
  ```
  Reso verificato con goreleaser 2.17 (`generate_completions_from_executable "checkfleet", "completion", shells: [:bash, :zsh, :fish]`): Homebrew risolve il nome sul binario **staged** e lo esegue a install-time passando il nome shell come argomento nudo — combacia con la CLI. Se falliscono sono warning, non install rotta. Da aggiungere poi un assert in `cask-ci.yml` (i file completion esistono dopo l'install).
- [ ] **HT-2 — `desc` senza articolo** (**upstream**): `brew style` segnala `Cask/Desc: Description shouldn't start with an article` su `desc "A fleet of..."`. Si sistema cambiando `description:` in `.goreleaser.yaml` (es. `Fleet of domain-aware infrastructure checks in one binary`). Quando la release successiva porta qui il cask corretto, togliere `Cask/Desc` da `--except-cops` in `cask-ci.yml` (resta solo `Layout/EmptyLinesAroundBlockBody`, che è il template di GoReleaser e non è correggibile da nessuna parte).
- [ ] **HT-7 — `caveats` nel cask CLI** (**upstream**): campo `caveats:` in `homebrew_casks` con due righe utili post-install (config d'esempio `checkfleet.example.yml`, link a `checkfleet check --help` e alle docs). Verificato che goreleaser lo rende come blocco `caveats <<~EOS`.
- [ ] **HT-8 — Versione reale nel bundle desktop** (**upstream**): `checkfleet.app/Contents/Info.plist` dichiara `CFBundleVersion`/`CFBundleShortVersionString` `1.0.0` fissi. Cosmetico per Homebrew (`brew upgrade` confronta la versione del cask, non il plist) ma bugiardo in "Info su" e nel Finder: iniettare la versione nel build Wails.
- [ ] **HT-9 — Desktop su Linux**: le release hanno anche `checkfleet-desktop_v*_linux_amd64.tar.gz`. Un cask con solo `binary` è installabile su Linuxbrew 6+, ma `app` no (artifact macOS-only), quindi servirebbe un cask separato o un ramo `on_linux` con `binary`. Valutare se qualcuno lo usa davvero prima di aggiungere superficie.

## Documentazione

- [x] **HT-6 — README del tap**: cosa contiene il tap, comandi espliciti con `--cask` (install/upgrade/uninstall/zap), nota sul *trust* dei tap di terze parti in Homebrew 6+, nota su Linux (i cask con solo `binary` si installano su Linuxbrew, quelli con `app` no), puntatore a "il contenuto è generato". _(qui)_
- [x] **HT-11 — Regole per gli agent**: `AGENTS.md` + `CLAUDE.md` con il confine generato/a-mano, il divieto di editare `Casks/`, i gate (`brew style`/`audit`) e le trappole (postflight quarantine, `livecheck skip`, race col push di GoReleaser). _(qui)_

## Deciso: non fare

- [x] **HT-12 — Formula per Linux**: ~~aggiungere `brews:` in goreleaser per coprire Linuxbrew~~. **Non serve**: un cask i cui artifact sono solo `binary` non è macOS-only — `Cask::Artifact::Binary` non è in `MACOS_ONLY_ARTIFACTS` — quindi `checkfleet` si installa già su Linuxbrew 6+, i blocchi `on_linux` del cask generato sono reali e il postflight `xattr` si auto-salta lì (è dietro un `system_command "/usr/bin/xattr", args: ["-h"]`). Una formula in più sarebbe solo un secondo posto dove sbagliare la versione. _(deciso 2026-07-26)_
- [x] **HT-13 — Stanza `license` nei cask**: ~~esporre PolyForm-Noncommercial nel cask~~. **Impossibile**: il DSL dei cask non ha `license` (non è in `Cask::DSL::DSL_METHODS`); il campo `license:` di goreleaser viene accettato e **scartato silenziosamente** in fase di render (verificato). La licenza resta nel repo upstream e negli archivi. _(deciso 2026-07-26)_
- [x] **HT-14 — `.rubocop.yml` nel tap**: ~~escludere i cop del file generato da config invece che da CLI~~. **Non funziona**: `brew style` forza `--config $(brew --prefix)/Library/.rubocop.yml`, quindi la config del tap viene ignorata (verificato: le esclusioni non hanno effetto né nel repo né dentro Library/Taps). Le esclusioni vivono in `cask-ci.yml` come `--except-cops`, con puntatore a HT-2. _(deciso 2026-07-26)_
- [x] **HT-15 — `livecheck` reale**: ~~sostituire `skip` con un livecheck sui tag upstream~~. **Non fare**: la versione la spinge la release (goreleaser per il CLI, `desktop-cask.yml` per l'app). Un livecheck sarebbe una seconda fonte di verità che può divergere. _(deciso 2026-07-26)_
- [x] **HT-16 — `zap` per il cask CLI**: ~~aggiungere path da ripulire~~. **Non serve**: la CLI non scrive stato in `~/Library` né in home — la history è opt-in con `--history PATH` esplicito. Il `# No zap stanza required` generato è corretto. (Il cask desktop invece ha `zap`: l'app usa WebKit e le preferenze del bundle.) _(deciso 2026-07-26)_
