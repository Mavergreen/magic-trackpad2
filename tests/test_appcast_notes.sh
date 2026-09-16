#!/bin/sh
# Asserts shipyard's gen_appcast.sh renders our Markdown release notes to the expected HTML fragment
# (Sparkle shows <description> in a WebView; raw Markdown collapses to one blob).
#
#   test_appcast_notes.sh [SHIPYARD_SCRIPTS_DIR]
#
# ctest passes ${MavericksShipyard_SCRIPTS} (the configure already required shipyard). Run by hand, it
# falls back to $SHIPYARD_SCRIPTS (exported by shipyard's install@v1) and then msc.sh's shipyard-cmake
# probe. Not finding shipyard is a SKIP (77, ctest's SKIP_RETURN_CODE), never a pass: this used to
# look under the pre-rename MavericksSharedCMake registry entry and exit 0 on a miss, so once the
# package became MavericksShipyard it "passed" without rendering anything.
set -e
here=$(dirname "$0")
root=$(cd "$here/.." && pwd)
scripts="${1:-${SHIPYARD_SCRIPTS:-}}"
if [ -z "$scripts" ]; then
  # In a subshell, tolerating failure: msc.sh EXITS when it finds nothing, and this test must SKIP.
  scripts="$(. "$root/msc.sh" >/dev/null 2>&1 && printf '%s' "$SHIPYARD")" || scripts=""
fi
gen="$scripts/gen_appcast.sh"
[ -f "$gen" ] || { echo "SKIP: mavericks-shipyard not installed (no gen_appcast.sh at '$gen')"; exit 77; }

tmp="${TMPDIR:-/tmp}/mt2-appcast-notes.$$"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

# --- synthetic fixture exercising every construct ---------------------------------------------------
cat > "$tmp/notes.md" <<'MD'
## Title X

Lead para with **bold** and *italic* words.

- a
- item **two** spanning
  a continuation line
- three

Requires macOS 10.9.5 or later.
MD

out=$(sh "$gen" --render-notes "$tmp/notes.md")

check() { echo "$out" | grep -qF "$1" || { echo "FAIL: missing [$1]"; echo "--- rendered ---"; echo "$out"; exit 1; }; }

check '<h2>Title X</h2>'
check '<p>Lead para with <strong>bold</strong> and <em>italic</em> words.</p>'
check '<ul>'
check '<li>a</li>'
check '<li>item <strong>two</strong> spanning a continuation line</li>'   # continuation folds in
check '<li>three</li>'
check '</ul>'
check '<p>Requires macOS 10.9.5 or later.</p>'

# raw Markdown markers must NOT leak into the HTML
if echo "$out" | grep -qE '(\*\*|^- |^## )'; then
  echo "FAIL: raw Markdown leaked into rendered HTML"; echo "$out"; exit 1
fi

# --- real shipped notes: no title of its own (release-notes.sh supplies that), a bullet must render ---
# (v0.3.0.md is hand-authored prose only, per release-notes/README.md -- it must NOT start with its
# own '## ' heading, so there is no <h2> to check for here.)
real=$(sh "$gen" --render-notes "$root/release-notes/v0.3.0.md")
echo "$real" | grep -qF '<ul>' || { echo "FAIL: v0.3.0 has no list"; echo "$real"; exit 1; }
echo "$real" | grep -qF '<strong>Check for Updates, in the pane</strong>' || { echo "FAIL: v0.3.0 bold bullet lead"; echo "$real"; exit 1; }

# full appcast path also embeds the rendered HTML (not raw Markdown) inside the CDATA
full=$(sh "$gen" "Mavericks Trackpad 2" 0.3.0 https://example/pkg 10.9.5 "$root/release-notes/v0.3.0.md" 'sparkle:edSignature="x" length="1"')
echo "$full" | grep -qF '<strong>Check for Updates, in the pane</strong>' || { echo "FAIL: appcast lacks rendered prose"; echo "$full"; exit 1; }

echo OK
