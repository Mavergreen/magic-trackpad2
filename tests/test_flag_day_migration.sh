#!/bin/sh
# Behaviour test for dist/scripts/flag-day-migration.sh -- the ONE-TIME MIGRATION off the ModernMavericks
# identity (flag day 2026-09-22). DELETABLE with it, once no pre-flag-day install survives (see shipyard
# SKILL.md "Consolidation backlog").
#
# Runs the real helper against a FAKE target volume (a temp dir standing in for Installer's $3), with
# launchctl / pkgutil / sudo / stat stubbed on PATH to record what they were asked to do. Nothing here
# touches the real /Library, /Users or the live launchd. What it cannot reach: the boot-volume launchctl
# unloads (they only run when $3 is "/"), which is why a non-boot target must NOT call launchctl at all.
set -u
D="$(cd "$(dirname "$0")/.." && pwd)"
MIG="$D/dist/scripts/flag-day-migration.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/flagday.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
fail=0
pass() { echo "PASS: $1"; }
bad()  { echo "FAIL: $1"; fail=1; }

STUBS="$TMP/stubs"; LOG="$TMP/calls"; mkdir -p "$STUBS"; : > "$LOG"
for c in launchctl pkgutil sudo stat; do
    printf '#!/bin/sh\necho "%s $*" >> "%s"\n' "$c" "$LOG" > "$STUBS/$c"; chmod +x "$STUBS/$c"
done
run() { PATH="$STUBS:$PATH" sh "$MIG" "$@"; }

OLD=dev.modernmavericks.voodooinputmavericks
NEW=dev.mavergreen.voodooinputmavericks
VOL="$TMP/vol"
mkdir -p "$VOL/Library/LaunchDaemons" "$VOL/Library/LaunchAgents" \
         "$VOL/Users/alice/Library/Preferences" "$VOL/Users/bob/Library/Preferences" \
         "$VOL/Users/carol/Library/Preferences"
for p in "LaunchDaemons/$OLD" "LaunchDaemons/$OLD.linkstated" "LaunchAgents/$OLD.session" \
         "LaunchDaemons/$NEW" "LaunchDaemons/$NEW.linkstated" "LaunchAgents/$NEW.session" \
         "LaunchAgents/$OLD.updatecheck"; do
    echo "$p" > "$VOL/Library/$p.plist"
done
# alice: old updater prefs only -> carried. bob: already chose under the new identity -> not clobbered.
# carol: no old prefs -> nothing appears.
AP="$VOL/Users/alice/Library/Preferences"; BP="$VOL/Users/bob/Library/Preferences"
echo alice-old > "$AP/dev.modernmavericks.Trackpad2Updater.plist"; chmod 600 "$AP/dev.modernmavericks.Trackpad2Updater.plist"
echo bob-old   > "$BP/dev.modernmavericks.Trackpad2Updater.plist"
echo bob-new   > "$BP/dev.mavergreen.Trackpad2Updater.plist"

# --- no target volume: nothing is known about where the old install lives, so nothing is touched ---
run pre ""; run post ""
if [ -f "$VOL/Library/LaunchDaemons/$OLD.plist" ] && [ ! -s "$LOG" ]; then
    pass "empty target -> touches nothing, runs nothing"
else
    bad "empty target acted anyway (calls: $(cat "$LOG"))"
fi

# --- pre ---
run pre "$VOL/"
for p in "LaunchDaemons/$OLD" "LaunchDaemons/$OLD.linkstated" "LaunchAgents/$OLD.session"; do
    [ -e "$VOL/Library/$p.plist" ] && bad "pre left the pre-rename $p.plist" || pass "pre removes $p.plist"
done
for p in "LaunchDaemons/$NEW" "LaunchDaemons/$NEW.linkstated" "LaunchAgents/$NEW.session"; do
    [ -f "$VOL/Library/$p.plist" ] && pass "pre keeps the new $p.plist" || bad "pre removed the NEW $p.plist"
done
# The old update-check agent belongs to shipyard's agent-load snippet (sourced by the postinstall); a
# second retirement here would be a duplicate that drifts from the shared one.
[ -f "$VOL/Library/LaunchAgents/$OLD.updatecheck.plist" ] \
    && pass "pre leaves the update-check agent to the shared agent-load retirement" \
    || bad "pre duplicated the shared update-check retirement"
grep -q '^launchctl' "$LOG" && bad "pre ran launchctl for a NON-boot target (calls: $(cat "$LOG"))" \
    || pass "pre does not touch the running launchd for a non-boot target"

# --- post ---
: > "$LOG"
run post "$VOL/"
if grep -qx "pkgutil --volume $VOL/ --forget $OLD" "$LOG"; then pass "post forgets the pre-rename receipt on the target volume"
else bad "post did not forget $OLD on $VOL/ (calls: $(cat "$LOG"))"; fi
[ "$(cat "$AP/dev.mavergreen.Trackpad2Updater.plist" 2>/dev/null)" = alice-old ] \
    && pass "post carries a user's updater prefs to the renamed domain" \
    || bad "post did not carry alice's updater prefs"
[ "$(stat -f %Lp "$AP/dev.mavergreen.Trackpad2Updater.plist" 2>/dev/null)" = 600 ] \
    && pass "post keeps the prefs file's mode" || bad "post changed the prefs file's mode"
[ -f "$AP/dev.modernmavericks.Trackpad2Updater.plist" ] \
    && pass "post never deletes the old prefs (copy, not move)" || bad "post deleted the user's old prefs"
[ "$(cat "$BP/dev.mavergreen.Trackpad2Updater.plist")" = bob-new ] \
    && pass "post never clobbers a choice made under the new identity" || bad "post clobbered bob's new prefs"
[ -e "$VOL/Users/carol/Library/Preferences/dev.mavergreen.Trackpad2Updater.plist" ] \
    && bad "post invented prefs for a user who had none" || pass "post leaves a user with no old prefs alone"

# --- idempotent: a second install (e.g. a reinstall of the same version) changes nothing ---
run pre "$VOL/"; run post "$VOL/"
[ "$(cat "$AP/dev.mavergreen.Trackpad2Updater.plist")" = alice-old ] && pass "a second run is a no-op" \
    || bad "a second run changed the carried prefs"

# --- never hot-unloads the kext (Model A; see test_install_kext_load.sh) ---
grep -qE '^[^#]*kextunload' "$MIG" && bad "the migration kextunloads -> could tear down the live driver" \
    || pass "the migration never kextunloads"

# --- wiring: both pkg scripts run it against Installer's target volume ---
grep -q 'flag-day-migration.sh" pre "\$3"' "$D/dist/scripts/preinstall" \
    && pass "preinstall runs the pre phase on \$3" || bad "preinstall does not run the pre phase on \$3"
grep -q 'flag-day-migration.sh" post "\$3"' "$D/dist/scripts/postinstall" \
    && pass "postinstall runs the post phase on \$3" || bad "postinstall does not run the post phase on \$3"
# The shared retirement of the old update-check agent + updater app (shipyard updater/agent-load.in)
# derives the old label by swapping the dev.mavergreen. prefix and reads the target from $3, so it only
# works if the label is dev.mavergreen.* and the snippet is SOURCED (keeping $3), not run.
grep -q -- '--agent-label dev\.mavergreen\.voodooinputmavericks\.updatecheck' "$D/cmake/voodooinputmavericks_pkg.cmake" \
    && pass "update-check label is dev.mavergreen.* (shared retirement derives the old one)" \
    || bad "update-check label is not dev.mavergreen.voodooinputmavericks.updatecheck"
grep -qE '^[[:space:]]*\. "\$AGENT_LOAD"$' "$D/dist/scripts/postinstall" \
    && pass "postinstall sources agent-load with its own arguments" \
    || bad "postinstall does not source agent-load (the shared retirement would not see \$3)"

[ "$fail" = 0 ] && echo "ALL PASS: flag-day migration" || echo "FLAG-DAY MIGRATION BROKEN"
exit $fail
