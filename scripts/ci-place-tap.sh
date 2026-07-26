#!/usr/bin/env bash
# Mette il checkout dentro Library/Taps così che brew lo veda come il tap
# allan-nava/tap.
#
# Serve perché Homebrew rifiuta i cask fuori da un tap: `brew info --cask
# ./Casks/checkfleet.rb` risponde "Homebrew requires casks to be in a tap".
# Quindi in CI non si può validare il file "sul posto": va spostato.
#
# Uso: scripts/ci-place-tap.sh [dir-sorgente]   (default: $PWD)
#
# TAP_DIR può essere sovrascritto per provare senza toccare il tap installato in
# locale (che questo script cancella e ricrea):
#   TAP_DIR="$(brew --repository)/Library/Taps/allan-nava/homebrew-scratch" scripts/ci-place-tap.sh
set -euo pipefail

SRC="${1:-$PWD}"
TAP_DIR="${TAP_DIR:-$(brew --repository)/Library/Taps/allan-nava/homebrew-tap}"

mkdir -p "$(dirname "$TAP_DIR")"
rm -rf "$TAP_DIR"
cp -R "$SRC" "$TAP_DIR"

# Alcuni comandi brew vogliono un repo git: se il sorgente non lo era (o il
# checkout è senza .git), se ne crea uno usa-e-getta.
if [ ! -d "$TAP_DIR/.git" ]; then
  git -C "$TAP_DIR" init -q .
  git -C "$TAP_DIR" add -A
  git -C "$TAP_DIR" -c user.email=ci@local -c user.name=ci commit -qm "ci snapshot"
fi

echo "tap in $TAP_DIR"
