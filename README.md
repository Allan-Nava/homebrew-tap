# Homebrew Tap

Homebrew tap for Allan-Nava projects.

## Install

```bash
brew tap Allan-Nava/tap
brew install --cask checkfleet          # CLI
brew install --cask checkfleet-desktop  # desktop app (macOS)
brew install --cask segcheck            # CLI
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

All of them ship prebuilt release binaries — nothing is compiled from source. The
two `checkfleet` casks are unsigned, so they strip the `com.apple.quarantine`
attribute on install and Gatekeeper stays out of the way.

Note that `segcheck` is licensed
[PolyForm Noncommercial 1.0.0](https://github.com/Allan-Nava/segcheck/blob/main/LICENSE),
not under the same terms as `checkfleet`.

Linux users: `checkfleet` and `segcheck` install on Linuxbrew too (a cask whose only
artifact is a `binary` is not macOS-only). `checkfleet-desktop` ships a `.app`
bundle, so it is macOS-only — on Linux grab the desktop tarball from the
[releases page](https://github.com/Allan-Nava/checkfleet/releases).

## Upgrade / uninstall

```bash
brew upgrade --cask checkfleet
brew uninstall --cask checkfleet
brew uninstall --cask segcheck
brew uninstall --cask --zap checkfleet-desktop  # also removes app caches/preferences
```

## Maintenance

The cask files are **generated, not hand-written**:

- `Casks/checkfleet.rb`, `Casks/segcheck.rb` — written by GoReleaser on every `v*`
  tag in their own repository.
- `Casks/checkfleet-desktop.rb` — written by
  [`scripts/render-desktop-cask.sh`](scripts/render-desktop-cask.sh) through the
  [Desktop cask](.github/workflows/desktop-cask.yml) workflow (GoReleaser doesn't
  build the desktop app, so it can't generate that cask).

Every change is linted, loaded, installed and audited by
[Cask CI](.github/workflows/cask-ci.yml). Todos live in [BACKLOG.md](BACKLOG.md);
the rules for humans and AI agents working here are in [AGENTS.md](AGENTS.md) and
[CLAUDE.md](CLAUDE.md).
