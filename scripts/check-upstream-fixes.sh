#!/usr/bin/env bash
# Audita i cask generati per capire se i fix che aspettiamo da upstream sono
# arrivati.
#
# Diversi item del backlog non si possono chiudere qui: vanno fatti nel
# `.goreleaser.yaml` del progetto (checkfleet per HT-1/2/7, segcheck per HT-21) e
# arrivano con la release successiva. Questo script guarda i cask appena committati
# e dice quali sono atterrati, così il workflow apre una issue invece di lasciare
# che l'item invecchi nel BACKLOG.
#
# Stampa TSV: stato(landed|pending|done) <TAB> id <TAB> messaggio. Exit 0 sempre —
# "pending" è la normalità, non un errore.
#
#   pending  il fix non è ancora atterrato: si aspetta la release upstream
#   landed   è atterrato e **qui c'è ancora qualcosa da fare** (tipicamente
#            togliere l'esclusione da cask-ci.yml) → il workflow apre la issue
#   done     atterrato e già recepito: niente da fare, la issue va chiusa
#
# Lo stato `done` esiste perché senza di lui la issue "Fix upstream arrivato"
# diventava immortale: `gh-issue.sh ensure-open` riapre una issue chiusa, quindi
# una volta atterrato il fix la notifica tornava a ogni run anche dopo averla
# recepita — e chiuderla a mano non serviva a niente.
set -euo pipefail

CASK="${CASK:-Casks/checkfleet.rb}"
[ -f "$CASK" ] || { echo "check-upstream-fixes: $CASK non trovato" >&2; exit 1; }

# Cask di segcheck: sorvegliato per HT-21. Manca (o è rinominato) → l'unico check
# che lo riguarda si salta, gli altri restano validi.
SEGCHECK_CASK="${SEGCHECK_CASK:-Casks/segcheck.rb}"

# Il workflow dove vivono le esclusioni di `brew style`: è lì che si vede se un
# fix atterrato è già stato recepito.
CI_WORKFLOW="${CI_WORKFLOW:-.github/workflows/cask-ci.yml}"

# `excluded <Cop>` → vero se quel cop è ancora fra le esclusioni dei cask generati.
excluded() {
  [ -f "$CI_WORKFLOW" ] && grep -q -- "--except-cops" "$CI_WORKFLOW" && grep -q -- "$1" "$CI_WORKFLOW"
}

report() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

# HT-1 — completions shell installate dal cask.
if grep -q 'generate_completions_from_executable' "$CASK"; then
  report landed HT-1 "Il cask ora dichiara \`generate_completions_from_executable\`: le completions arrivano con l'install. Spunta HT-1 e aggiungi in \`cask-ci.yml\` l'assert che i file di completion esistano dopo \`brew install\`."
else
  report pending HT-1 "Il cask installa solo il binario: nessuna completion. Fix upstream in \`.goreleaser.yaml\` → \`homebrew_casks.generate_completions_from_executable\` (executable \`checkfleet\`, args \`[\"completion\"]\`, shells bash/zsh/fish)."
fi

# HT-2 — `desc` che inizia con un articolo (offense Cask/Desc).
if grep -Eq '^[[:space:]]*desc "(A|An|The) ' "$CASK"; then
  report pending HT-2 "\`desc\` inizia ancora con un articolo: \`brew style\` resta rosso senza l'esclusione \`Cask/Desc\`. Fix upstream: cambiare \`description:\` in \`.goreleaser.yaml\`."
elif excluded Cask/Desc; then
  report landed HT-2 "\`desc\` non inizia più con un articolo: togli \`Cask/Desc\` da \`--except-cops\` in \`cask-ci.yml\`, poi spunta HT-2."
else
  report "done" HT-2 "\`desc\` a posto e esclusione già rimossa: niente da fare."
fi

# HT-7 — caveats post-install.
if grep -q '^[[:space:]]*caveats' "$CASK"; then
  report landed HT-7 "Il cask ha un blocco \`caveats\`: spunta HT-7 e verifica che il testo sia quello voluto."
else
  report pending HT-7 "Nessun \`caveats\` nel cask: fix upstream con il campo \`caveats:\` in \`homebrew_casks\` (config d'esempio + link alle docs)."
fi

# HT-21 — `exit_status == 0` nel postflight di segcheck (offense
# Style/NumericPredicate). Il confronto va scritto `.zero?`, oppure il postflight
# va allineato a quello di checkfleet, che usa il valore di ritorno di
# `system_command` senza confrontare l'exit status.
if [ ! -f "$SEGCHECK_CASK" ]; then
  report pending HT-21 "\`$SEGCHECK_CASK\` non c'è: niente da controllare per HT-21 (cask rinominato o rimosso dal tap?)."
elif grep -Eq 'exit_status[[:space:]]*==[[:space:]]*0' "$SEGCHECK_CASK"; then
  report pending HT-21 "Il postflight di segcheck confronta ancora \`exit_status == 0\`: \`brew style\` resta rosso senza l'esclusione \`Style/NumericPredicate\`. Fix upstream nel \`.goreleaser.yaml\` di segcheck (\`.exit_status.zero?\`, o la forma usata da checkfleet)."
elif excluded Style/NumericPredicate; then
  report landed HT-21 "Il postflight di segcheck non confronta più \`exit_status == 0\`: togli \`Style/NumericPredicate\` da \`--except-cops\` in \`cask-ci.yml\`, poi spunta HT-21."
else
  report "done" HT-21 "Postflight a posto e esclusione già rimossa: niente da fare."
fi
