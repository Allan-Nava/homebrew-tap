# Homebrew Tap

Homebrew tap for Allan-Nava projects.

## Install

```bash
brew tap Allan-Nava/tap
brew install --cask checkfleet          # CLI
brew install --cask checkfleet-desktop  # desktop app (macOS)
brew install --cask segcheck            # CLI
brew install --cask ladder-bench        # CLI
brew install --cask abrsim              # CLI
```

Or in one shot, without tapping first:

```bash
brew install --cask Allan-Nava/tap/checkfleet
```

Homebrew 6+ may ask you to *trust* a third-party tap on first install
(`brew trust --cask Allan-Nava/tap/checkfleet`). That prompt is expected.

## What's in here

| Cask | What | Platforms |
| --- | --- | --- |
| `checkfleet` | [checkfleet](https://github.com/Allan-Nava/checkfleet) CLI — a fleet of domain-aware infrastructure checks in one binary | macOS `amd64`/`arm64`, Linux `amd64`/`arm64` |
| `checkfleet-desktop` | the Wails desktop app (`checkfleet.app`, universal binary) | macOS only |
| `segcheck` | [segcheck](https://github.com/Allan-Nava/segcheck) CLI — checks what HLS/DASH segments really contain, not just what the manifest says | macOS `amd64`/`arm64`, Linux `amd64`/`arm64` |
| `ladder-bench` | [ladder-bench](https://github.com/Allan-Nava/ladder-bench) CLI — measures an ABR encoding ladder with VMAF instead of inheriting it | macOS `amd64`/`arm64`, Linux `amd64`/`arm64` |
| `abrsim` | [abrsim](https://github.com/Allan-Nava/abrsim) CLI — simulates what an ABR player does with your HLS ladder on a real network, and reports what it cost the viewer | macOS `amd64`/`arm64`, Linux `amd64`/`arm64` |

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

Linux users: `checkfleet`, `segcheck`, `ladder-bench` and `abrsim` install on
Linuxbrew too (a cask whose only artifact is a `binary` is not macOS-only). `checkfleet-desktop` ships a `.app`
bundle, so it is macOS-only — on Linux grab the desktop tarball from the
[releases page](https://github.com/Allan-Nava/checkfleet/releases).

## Upgrade / uninstall

```bash
brew upgrade --cask checkfleet
brew uninstall --cask checkfleet
brew uninstall --cask segcheck
brew uninstall --cask ladder-bench
brew uninstall --cask abrsim
brew uninstall --cask --zap checkfleet-desktop  # also removes app caches/preferences
```

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

Every change is linted, loaded, installed and audited by
[Cask CI](.github/workflows/cask-ci.yml). Todos live in [BACKLOG.md](BACKLOG.md);
the rules for humans and AI agents working here are in [AGENTS.md](AGENTS.md) and
[CLAUDE.md](CLAUDE.md).
