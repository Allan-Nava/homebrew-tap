#!/usr/bin/env bash
# Rigenera dal contenuto di `Casks/*.rb` le parti del README che elencano i cask:
# i comandi di install, la tabella "What's in here" e i comandi di uninstall.
#
# Perché esiste (HT-27): il tap si aggiorna da sé — GoReleaser pusha il cask di un
# progetto nuovo senza che nessuno tocchi questo repo — ma il README no. È già
# successo: `abrsim` è entrata nel tap con due commit del bot ed è rimasta fuori da
# README, CLAUDE.md e AGENTS.md finché non se n'è accorto qualcuno. Un elenco
# scritto a mano di una cosa che cresce da sola invecchia per costruzione.
#
# Si generano SOLO gli elenchi, fra marker. La prosa attorno (quarantine, licenze,
# nota su Linux, ffmpeg) resta scritta a mano: è ciò che il README ha di utile e
# non si deduce da un cask.
#
# Uso:
#   scripts/render-readme-casks.sh           # riscrive README.md se serve
#   scripts/render-readme-casks.sh --check   # exit 1 se il README è stantio
#
# Non serve rete e non serve brew: legge i file dei cask e basta.
set -euo pipefail

README="${README:-README.md}"
CASKS_DIR="${CASKS_DIR:-Casks}"
MODE="write"   # SC2209: `write` è una stringa, non un comando
case "${1:-}" in
  --check) MODE=check ;;
  "") ;;
  -h | --help)
    sed -n '2,20p' "$0"
    exit 0
    ;;
  *) echo "render-readme-casks: opzione sconosciuta: $1" >&2 && exit 1 ;;
esac

die() { echo "render-readme-casks: $*" >&2; exit 1; }

[ -f "$README" ] || die "$README non trovato"

field() { # field <file> <stanza> → il valore fra apici doppi
  sed -n "s/^ *$2 \"\(.*\)\"$/\1/p" "$1" | head -1
}

# Le piattaforme si leggono dai blocchi `on_macos`/`on_linux` × `on_intel`/`on_arm`
# del cask generato. Un cask con artifact `app` (o `depends_on :macos`) è macOS-only
# per forza: `Cask::Artifact::App` è in MACOS_ONLY_ARTIFACTS, `binary` no — ed è per
# questo che i CLI si installano anche su Linuxbrew.
platforms() {
  local f="$1"
  if grep -q '^ *app "' "$f" || grep -q '^ *depends_on :macos' "$f"; then
    echo "macOS only"
    return
  fi
  local out
  out="$(awk '
    /^ *on_macos do/ { os = "macOS" }
    /^ *on_linux do/ { os = "Linux" }
    /^ *on_intel do/ { if (os) arch[os] = arch[os] (arch[os] ? "/" : "") "`amd64`" }
    /^ *on_arm do/   { if (os) arch[os] = arch[os] (arch[os] ? "/" : "") "`arm64`" }
    END {
      sep = ""
      if ("macOS" in arch) { printf "%smacOS %s", sep, arch["macOS"]; sep = ", " }
      if ("Linux" in arch) { printf "%sLinux %s", sep, arch["Linux"] }
    }
  ' "$f")"
  [ -n "$out" ] || out="macOS"
  echo "$out"
}

# `depends_on formula: [...]` su una o più righe → "ffmpeg, x264"
formulae() {
  awk '
    /^ *depends_on formula:/ { inblock = 1 }
    inblock {
      while (match($0, /"[^"]+"/)) {
        name = substr($0, RSTART + 1, RLENGTH - 2)
        list = list (list ? ", " : "") name
        $0 = substr($0, RSTART + RLENGTH)
      }
      if (/\]/ || !/\[/) inblock = 0
    }
    END { print list }
  ' "$1"
}

tokens=()
while IFS= read -r f; do tokens+=("$(basename "$f" .rb)"); done < <(find "$CASKS_DIR" -maxdepth 1 -name '*.rb' | sort)
[ "${#tokens[@]}" -gt 0 ] || die "nessun cask in $CASKS_DIR"

# I CLI prima e le app dopo, ognuno in ordine alfabetico: è l'ordine in cui uno
# legge la tabella, e non dipende da chi è entrato nel tap per primo.
clis=()
apps=()
for t in "${tokens[@]}"; do
  if grep -q '^ *app "' "$CASKS_DIR/$t.rb"; then apps+=("$t"); else clis+=("$t"); fi
done
ordered=("${clis[@]}" "${apps[@]}")

# Larghezza del token più lungo, per allineare i commenti nei blocchi di comandi.
width=0
for t in "${ordered[@]}"; do [ "${#t}" -gt "$width" ] && width="${#t}"; done

block_install() {
  echo '```bash'
  echo 'brew tap Allan-Nava/tap'
  for t in "${ordered[@]}"; do
    if grep -q '^ *app "' "$CASKS_DIR/$t.rb"; then
      printf 'brew install --cask %-*s  # desktop app (macOS)\n' "$width" "$t"
    else
      printf 'brew install --cask %-*s  # CLI\n' "$width" "$t"
    fi
  done
  echo '```'
}

block_table() {
  echo '| Cask | What | Platforms |'
  echo '| --- | --- | --- |'
  local t desc home kind dep
  for t in "${ordered[@]}"; do
    desc="$(field "$CASKS_DIR/$t.rb" desc)"
    home="$(field "$CASKS_DIR/$t.rb" homepage)"
    dep="$(formulae "$CASKS_DIR/$t.rb")"
    label="$(field "$CASKS_DIR/$t.rb" name)"
    [ -n "$label" ] || label="$t"
    # "CLI" solo dove serve distinguere: per un'app il `desc` dice già che è
    # un'app, e "desktop app — Desktop app to..." non aiuta nessuno.
    if grep -q '^ *app "' "$CASKS_DIR/$t.rb"; then kind=""; else kind=" CLI"; fi
    [ -n "$dep" ] && desc="$desc (needs \`$dep\`)"
    # shellcheck disable=SC2016 # i backtick sono markdown, non command substitution
    printf '| `%s` | [%s](%s)%s — %s | %s |\n' \
      "$t" "$label" "$home" "$kind" "$desc" "$(platforms "$CASKS_DIR/$t.rb")"
  done
}

block_uninstall() {
  local t
  echo '```bash'
  echo 'brew upgrade --cask                 # every installed cask, this tap included'
  for t in "${ordered[@]}"; do
    if grep -q '^ *zap ' "$CASKS_DIR/$t.rb"; then
      # `--zap` solo dove il cask ha davvero una stanza zap, altrimenti si
      # promette una pulizia che non esiste.
      printf 'brew uninstall --cask --zap %s  # also removes app caches/preferences\n' "$t"
    else
      printf 'brew uninstall --cask %s\n' "$t"
    fi
  done
  echo '```'
}

# Sostituisce ciò che sta fra i marker, lasciando i marker al loro posto. Se un
# marker manca è un errore: meglio fermarsi che aggiungere un blocco a caso in
# mezzo al README.
replace_region() {
  local name="$1" content_file="$2" src="$3" dst="$4"
  local begin="<!-- BEGIN generated: ${name} (scripts/render-readme-casks.sh) -->"
  local end="<!-- END generated: ${name} -->"
  grep -qF "$begin" "$src" || die "manca il marker di inizio '$name' in $README"
  grep -qF "$end" "$src" || die "manca il marker di fine '$name' in $README"
  awk -v b="$begin" -v e="$end" -v cf="$content_file" '
    index($0, b) { print; while ((getline line < cf) > 0) print line; close(cf); skip = 1; next }
    index($0, e) { skip = 0 }
    !skip { print }
  ' "$src" > "$dst"
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

block_install > "$tmp/install"
block_table > "$tmp/table"
block_uninstall > "$tmp/uninstall"

cp "$README" "$tmp/work"
for region in install table uninstall; do
  replace_region "$region" "$tmp/$region" "$tmp/work" "$tmp/next"
  mv "$tmp/next" "$tmp/work"
done

if cmp -s "$README" "$tmp/work"; then
  echo "README già allineato ai cask (${#ordered[@]} cask)."
  exit 0
fi

if [ "$MODE" = check ]; then
  echo "README stantio: gli elenchi non combaciano con Casks/. Diff:" >&2
  diff -u "$README" "$tmp/work" >&2 || true
  echo "Rigenera con: scripts/render-readme-casks.sh" >&2
  exit 1
fi

cat "$tmp/work" > "$README"
echo "README aggiornato (${#ordered[@]} cask)."
