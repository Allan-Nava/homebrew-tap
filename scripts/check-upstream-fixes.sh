#!/usr/bin/env bash
# Audita il cask generato per capire se i fix che aspettiamo da upstream sono
# arrivati.
#
# Diversi item del backlog non si possono chiudere qui: vanno fatti in
# `.goreleaser.yaml` di checkfleet e arrivano con la release successiva. Questo
# script guarda il cask appena committato e dice quali sono atterrati, così il
# workflow apre una issue invece di lasciare che l'item invecchi nel BACKLOG.
#
# Stampa TSV: stato(landed|pending) <TAB> id <TAB> messaggio. Exit 0 sempre —
# "pending" è la normalità, non un errore.
set -euo pipefail

CASK="${CASK:-Casks/checkfleet.rb}"
[ -f "$CASK" ] || { echo "check-upstream-fixes: $CASK non trovato" >&2; exit 1; }

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
else
  report landed HT-2 "\`desc\` non inizia più con un articolo: togli \`Cask/Desc\` da \`--except-cops\` in \`cask-ci.yml\` e \`desktop-cask.yml\`, poi spunta HT-2."
fi

# HT-7 — caveats post-install.
if grep -q '^[[:space:]]*caveats' "$CASK"; then
  report landed HT-7 "Il cask ha un blocco \`caveats\`: spunta HT-7 e verifica che il testo sia quello voluto."
else
  report pending HT-7 "Nessun \`caveats\` nel cask: fix upstream con il campo \`caveats:\` in \`homebrew_casks\` (config d'esempio + link alle docs)."
fi
