#!/bin/sh
# platform: host-agnostic
set -eu
R="$(cd "$(dirname "$0")/.." && pwd)"
W="$(mktemp -d "${TMPDIR:-/tmp}/t2-hooks.XXXXXX")"; trap 'rm -rf "$W"' EXIT
fail() { echo "FAIL: $1"; exit 1; }
mkdir -p "$W/stub"
for c in launchctl kextstat kextload kextunload killall open sleep chown; do printf '#!/bin/sh\necho "%s $*" >> "%s/calls"\n' "$c" "$W" > "$W/stub/$c"; chmod +x "$W/stub/$c"; done
V="$W/vol"; K="$V/usr/local/mavergreen/trackpad2/lib/VoodooInputMavericks.kext/Contents"; mkdir -p "$K"
S="$V/usr/local/mavergreen/var/trackpad2"
: > "$W/calls"
ROOT="$V" PATH="$W/stub:$PATH" sh "$R/dist/hooks/preinstall.sh" || fail "the preinstall hook must succeed on another volume"
ROOT="$V" PATH="$W/stub:$PATH" sh "$R/dist/hooks/postinstall.sh" > "$W/out" || fail "the postinstall hook must succeed on another volume"
grep -qv '^chown ' "$W/calls" && fail "installing to another volume must not load, unload or probe anything: $(cat "$W/calls")"
grep -q "^chown -R root:wheel $V/usr/local/mavergreen/trackpad2/lib/VoodooInputMavericks.kext" "$W/calls" \
  || fail "the kext on the TARGET volume is made root:wheel, as kextload requires"
[ "$(cat "$S/boot.state")" = ok ] || fail "the boot sentinel is reset to ok in var/trackpad2"
[ "$(ls -l "$S/session.trigger" | cut -c1-10)" = -rw-rw-rw- ] || fail "the session trigger exists, world-writable, in var/trackpad2"
echo keep > "$S/session.trigger"; echo trying > "$S/boot.state"
ROOT="$V" PATH="$W/stub:$PATH" sh "$R/dist/hooks/postinstall.sh" > "$W/out" || fail "the postinstall hook must succeed on an upgrade"
[ "$(cat "$S/session.trigger")" = keep ] || fail "an upgrade keeps the existing trigger file"
[ "$(cat "$S/boot.state")" = ok ] || fail "an upgrade resets the sentinel, so a fresh driver gets a full-gesture attempt"
grep -q 'https://mavericksforever.com/downloads/SIMBL.pkg' "$W/out" || fail "with no SIMBL on the volume, the hook says where to get it"
grep -q kextunload "$R/dist/hooks/preinstall.sh" && fail "the preinstall must never kextunload a live driver"
echo "PASS: test_install_hooks"
