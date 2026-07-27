#!/usr/bin/env bash
# Issue GitHub idempotente, identificata dal titolo esatto.
#
# Serve ai workflow per segnalare uno stato che va e viene (CI rossa, fix upstream
# arrivato) senza accumulare doppioni né commenti a ogni run:
#
#   scripts/gh-issue.sh ensure-open   "<titolo>" <file-body> [label...]
#   scripts/gh-issue.sh ensure-closed "<titolo>" "<commento>"
#
# ensure-open: crea la issue se manca, la riapre (con commento) se era chiusa,
# non fa nulla se è già aperta. ensure-closed: la chiude se è aperta, altrimenti
# non fa nulla.
#
# DRY_RUN=1 stampa le azioni senza eseguirle. Richiede gh e jq.
set -euo pipefail

action="${1:-}"
title="${2:-}"
DRY_RUN="${DRY_RUN:-0}"

usage() {
  echo "uso: $0 ensure-open <titolo> <file-body> [label...] | ensure-closed <titolo> <commento>" >&2
  exit 1
}
if [ -z "$action" ] || [ -z "$title" ]; then
  usage
fi

command -v gh >/dev/null || { echo "gh-issue: serve gh" >&2; exit 1; }
command -v jq >/dev/null || { echo "gh-issue: serve jq" >&2; exit 1; }

# Match sul titolo esatto: le issue di stato hanno titoli fissi, scelti per questo.
found="$(gh issue list --state all --limit 300 --json number,title,state |
  jq -r --arg t "$title" '.[] | select(.title == $t) | "\(.number)\t\(.state)"' | head -1)"
number="${found%%$'\t'*}"
state="${found#*$'\t'}"

case "$action" in
ensure-open)
  body_file="${3:-}"
  [ -f "$body_file" ] || usage
  shift 3 || true
  if [ -z "$found" ]; then
    echo "gh-issue: apro '$title'"
    if [ "$DRY_RUN" = "0" ]; then
      for label in "$@"; do
        gh label create "$label" --color d93f0b --description "Aperta automaticamente dai workflow del tap" >/dev/null 2>&1 || true
      done
      args=(issue create --title "$title" --body-file "$body_file")
      for label in "$@"; do
        args+=(--label "$label")
      done
      gh "${args[@]}" </dev/null
    fi
  elif [ "$state" = "CLOSED" ]; then
    echo "gh-issue: riapro #$number '$title'"
    if [ "$DRY_RUN" = "0" ]; then
      gh issue reopen "$number" </dev/null >/dev/null
      gh issue comment "$number" --body-file "$body_file" </dev/null >/dev/null
    fi
  else
    echo "gh-issue: #$number già aperta, non commento (niente rumore a ogni run)"
  fi
  ;;
ensure-closed)
  comment="${3:-Risolto.}"
  if [ -n "$found" ] && [ "$state" = "OPEN" ]; then
    echo "gh-issue: chiudo #$number '$title'"
    if [ "$DRY_RUN" = "0" ]; then
      gh issue close "$number" --comment "$comment" </dev/null >/dev/null
    fi
  else
    echo "gh-issue: niente da chiudere per '$title'"
  fi
  ;;
*)
  usage
  ;;
esac
