# Homebrew Tap

Homebrew tap for Allan-Nava projects.

## Install

<!-- BEGIN generated: install (scripts/render-readme-casks.sh) -->
```bash
brew tap Allan-Nava/tap
brew install --cask abrsim              # CLI
brew install --cask checkfleet          # CLI
brew install --cask galera-doctor       # CLI
brew install --cask ladder-bench        # CLI
brew install --cask segcheck            # CLI
brew install --cask checkfleet-desktop  # desktop app (macOS)
```
<!-- END generated: install -->

Or in one shot, without tapping first:

```bash
brew install --cask Allan-Nava/tap/checkfleet
```

Homebrew 6+ may ask you to *trust* a third-party tap on first install
(`brew trust --cask Allan-Nava/tap/checkfleet`). That prompt is expected.

## What's in here

<!-- BEGIN generated: table (scripts/render-readme-casks.sh) -->
| Cask | What | Platforms |
| --- | --- | --- |
| `abrsim` | [abrsim](https://github.com/Allan-Nava/abrsim) CLI — Simulate what an ABR player does with your HLS ladder on a real network, and report what it cost the viewer | macOS `amd64`/`arm64`, Linux `amd64`/`arm64` |
| `checkfleet` | [checkfleet](https://github.com/Allan-Nava/checkfleet) CLI — A fleet of domain-aware infrastructure checks in one binary | macOS `amd64`/`arm64`, Linux `amd64`/`arm64` |
| `galera-doctor` | [galera-doctor](https://github.com/Allan-Nava/galera-doctor) CLI — Read-only audit of a Galera cluster: the states its own metrics cannot show | macOS `arm64`/`amd64`, Linux `arm64`/`amd64` |
| `ladder-bench` | [ladder-bench](https://allan-nava.github.io/ladder-bench/) CLI — Measure your ABR encoding ladder instead of inheriting it (needs `ffmpeg`) | macOS `amd64`/`arm64`, Linux `amd64`/`arm64` |
| `segcheck` | [segcheck](https://github.com/Allan-Nava/segcheck) CLI — Check what HLS/DASH segments really contain, not just what the manifest says | macOS `amd64`/`arm64`, Linux `amd64`/`arm64` |
| `checkfleet-desktop` | [checkfleet Desktop](https://github.com/Allan-Nava/checkfleet) — Desktop app to run the checkfleet infrastructure checks | macOS only |
<!-- END generated: table -->

All of them ship prebuilt release binaries — nothing is compiled from source. None
of them is signed or notarized, so every cask strips the `com.apple.quarantine`
attribute on install and Gatekeeper stays out of the way. Without that, an unsigned
CLI does not get the "unidentified developer" dialog a GUI app gets — it dies on
SIGKILL with no output at all, which reads like a broken build.

`ladder-bench` is the only cask here with a dependency: it pulls in **ffmpeg**,
because it measures with libvmaf and that is a compile-time option of ffmpeg —
Homebrew's build has it, so installing the cask lands on a tool that can measure
rather than one that can only print its help. Whatever ffmpeg comes first on your
PATH still wins at run time; `ladder-bench doctor` says which one it found.

Licensing is not uniform: `checkfleet`, `segcheck` and `abrsim` are
[PolyForm Noncommercial 1.0.0](https://github.com/Allan-Nava/segcheck/blob/main/LICENSE)
(free for noncommercial use), while `ladder-bench` is MIT. Check the upstream
repository before using any of them at work.

Linux users: every CLI cask here installs on Linuxbrew too — a cask whose only
artifact is a `binary` is not macOS-only, so the `on_linux` branches above are real.
`checkfleet-desktop` ships a `.app` bundle, which *is* a macOS-only artifact — on
Linux grab the desktop tarball from the
[releases page](https://github.com/Allan-Nava/checkfleet/releases).

## Upgrade / uninstall

<!-- BEGIN generated: uninstall (scripts/render-readme-casks.sh) -->
```bash
brew upgrade --cask                 # every installed cask, this tap included
brew uninstall --cask abrsim
brew uninstall --cask checkfleet
brew uninstall --cask galera-doctor
brew uninstall --cask ladder-bench
brew uninstall --cask segcheck
brew uninstall --cask --zap checkfleet-desktop  # also removes app caches/preferences
```
<!-- END generated: uninstall -->

## Maintenance

The cask files are **generated, not hand-written**:

- `Casks/checkfleet.rb`, `Casks/segcheck.rb`, `Casks/ladder-bench.rb`,
  `Casks/abrsim.rb` — written by GoReleaser on every `v*` tag in their own
  repository. If that push ever fails (an expired tap token, typically), the
  [Cask sync](.github/workflows/cask-sync.yml) workflow notices within six hours,
  rebuilds the cask from the release assets and opens an issue.
- `Casks/checkfleet-desktop.rb` — written by
  [`scripts/render-desktop-cask.sh`](scripts/render-desktop-cask.sh) through the
  [Desktop cask](.github/workflows/desktop-cask.yml) workflow (GoReleaser doesn't
  build the desktop app, so it can't generate that cask).

The cask lists in this file — the install commands, the table above and the
uninstall commands — are generated from `Casks/*.rb` by
[`scripts/render-readme-casks.sh`](scripts/render-readme-casks.sh), between
`<!-- BEGIN generated: … -->` markers. Edit the prose freely, but run that script
(or let [Cask sync](.github/workflows/cask-sync.yml) do it) instead of hand-editing
the lists.

Every change is linted, loaded, installed and audited by
[Cask CI](.github/workflows/cask-ci.yml). Todos live in [BACKLOG.md](BACKLOG.md);
the rules for humans and AI agents working here are in [AGENTS.md](AGENTS.md) and
[CLAUDE.md](CLAUDE.md). Why this tap exists at all, and what it deliberately does
not do, is in [INTENT.md](INTENT.md).
