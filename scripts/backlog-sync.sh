#!/usr/bin/env bash
# Tiene le issue GitHub allineate a BACKLOG.md.
#
# BACKLOG.md è la sorgente unica: ogni item `HT-n` diventa una issue con label
# `backlog` e milestone = titolo della sezione. Spuntare un item (`[x]`) chiude
# la issue al sync successivo, togliere la spunta la riapre. Idempotente — le
# issue si riconoscono dal prefisso `HT-n` nel titolo — quindi si può rilanciare
# quante volte si vuole (in locale o da .github/workflows/backlog-sync.yml).
#
# Uso:
#   scripts/backlog-sync.sh [--dry-run]
#
# Richiede gh (autenticato o GH_TOKEN) e jq. In CI: GH_TOKEN + GH_REPO.
set -euo pipefail

BACKLOG="${BACKLOG:-BACKLOG.md}"
LABEL="backlog"
DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

command -v gh >/dev/null || { echo "backlog-sync: serve gh" >&2; exit 1; }
command -v jq >/dev/null || { echo "backlog-sync: serve jq" >&2; exit 1; }
[ -f "$BACKLOG" ] || { echo "backlog-sync: $BACKLOG non trovato" >&2; exit 1; }

# Estrae gli item come TSV: id, done(0|1), titolo, milestone, descrizione.
# Il titolo è quello che sta fra i `**` (già nella forma "HT-n — Nome"), la
# descrizione è il resto della riga: è il primo paragrafo dell'item, non tutto
# il blocco (gli item con esempi di codice restano leggibili nel file).
parse_backlog() {
  awk '
    /^##[[:space:]]/ {
      line = $0
      sub(/^##[[:space:]]+/, "", line)
      sub(/[[:space:]]+\(.*$/, "", line)   # via la coda "(qualcosa)" nel titolo di sezione
      milestone = line
      next
    }
    /^[[:space:]]*-[[:space:]]*\[[ xX]\][[:space:]]*\*\*HT-[0-9]+/ {
      line = $0
      done = (line ~ /^[[:space:]]*-[[:space:]]*\[[xX]\]/) ? "1" : "0"
      match(line, /HT-[0-9]+/)
      id = substr(line, RSTART, RLENGTH)
      rest = substr(line, index(line, "**") + 2)
      end = index(rest, "**")
      title = substr(rest, 1, end - 1)
      gsub(/`/, "", title)
      desc = substr(rest, end + 2)
      sub(/^[[:space:]]*:[[:space:]]*/, "", desc)
      printf "%s\t%s\t%s\t%s\t%s\n", id, done, title, milestone, desc
    }
  ' "$1"
}

items="$(parse_backlog "$BACKLOG")"
[ -n "$items" ] || { echo "backlog-sync: nessun item HT-n in $BACKLOG" >&2; exit 1; }

run_gh() {
  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi
  gh "$@"
}

# Label: best-effort, se esiste già va bene così.
if [ "$DRY_RUN" -eq 0 ]; then
  gh label create "$LABEL" --color 5319e7 \
    --description "Item di BACKLOG.md (HT-n), sincronizzato da backlog-sync.sh" >/dev/null 2>&1 || true
fi

# Milestone mancanti. --paginate perché di default l'API ne restituisce 30 per
# pagina: senza, le più recenti cadono fuori e si tenta di ricrearle (422).
existing_ms="$(gh api --paginate 'repos/{owner}/{repo}/milestones?state=all&per_page=100' --jq '.[].title' || true)"
printf '%s\n' "$items" | cut -f4 | sort -u | while IFS= read -r ms; do
  [ -n "$ms" ] || continue
  if printf '%s\n' "$existing_ms" | grep -Fxq "$ms"; then
    continue
  fi
  echo "  milestone  $ms"
  # Tollera una milestone comparsa nel frattempo: lo stato desiderato c'è già.
  run_gh api -X POST 'repos/{owner}/{repo}/milestones' -f "title=$ms" >/dev/null 2>&1 || true
done

issues_json="$(gh issue list --state all --limit 300 --json number,title,state)"

created=0
closed=0
reopened=0
unchanged=0

# Il ciclo legge dal fd 3: sullo stdin ci sono i comandi gh, che altrimenti si
# mangerebbero le righe rimanenti degli item.
#
# La variabile si chiama is_done e non done: con `read ... done` il linter
# (SC1010) crede che il ciclo finisca lì, ed è comunque un nome da evitare.
while IFS=$'\t' read -r id is_done title milestone desc <&3; do
  [ -n "$id" ] || continue

  found="$(printf '%s' "$issues_json" |
    jq -r --arg id "$id" '.[] | select(.title | startswith($id + " ")) | "\(.number)\t\(.state)"' |
    head -1)"
  number="${found%%$'\t'*}"
  state="${found#*$'\t'}"

  # Gli apici singoli sono voluti: i backtick qui sono markdown per il corpo
  # della issue, non command substitution (SC2016).
  # shellcheck disable=SC2016
  body="$(
    printf '%s\n\n---\n' "$desc"
    printf 'Tracciata in `BACKLOG.md` (**%s**) · milestone _%s_.\n\n' "$id" "$milestone"
    printf 'Gestita da `scripts/backlog-sync.sh`: si edita il **BACKLOG**, non questa issue. '
    printf 'Spuntando l item con `[x]` la issue viene chiusa al prossimo sync.\n'
  )"

  if [ -z "$found" ]; then
    created=$((created + 1))
    echo "  creo     $id ($milestone)"
    if [ "$DRY_RUN" -eq 0 ]; then
      args=(issue create --title "$title" --body "$body" --label "$LABEL")
      if [ -n "$milestone" ]; then
        args+=(--milestone "$milestone")
      fi
      url="$(gh "${args[@]}" </dev/null)"
      # Un item già fatto entra come issue chiusa: serve la storia, non un todo.
      if [ "$is_done" = "1" ]; then
        gh issue close "${url##*/}" --comment "Già completata in BACKLOG.md." </dev/null >/dev/null
      fi
    fi
    continue
  fi

  if [ "$is_done" = "1" ] && [ "$state" = "OPEN" ]; then
    closed=$((closed + 1))
    echo "  chiudo   $id (#$number)"
    run_gh issue close "$number" --comment "Completata: item spuntato in BACKLOG.md." >/dev/null
  elif [ "$is_done" = "0" ] && [ "$state" = "CLOSED" ]; then
    reopened=$((reopened + 1))
    echo "  riapro   $id (#$number)"
    run_gh issue reopen "$number" >/dev/null
  else
    unchanged=$((unchanged + 1))
  fi
done 3<<EOF
$items
EOF

total="$(printf '%s\n' "$items" | wc -l | tr -d ' ')"
echo "backlog-sync: $total item · $created create, $closed chiuse, $reopened riaperte, $unchanged invariate (dry-run=$DRY_RUN)"
