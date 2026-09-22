#!/bin/sh
# ONE-TIME MIGRATION off the ModernMavericks identity (flag day 2026-09-22).
# DELETABLE once no pre-flag-day install survives (see shipyard SKILL.md "Consolidation backlog").
#
# usage: flag-day-migration.sh pre|post TARGET_VOLUME
#   pre   run by the preinstall, before the payload lands
#   post  run by the postinstall, after it
#
# The org became Mavergreen and every installed identifier moved dev.modernmavericks.* ->
# dev.mavergreen.*. Installer never removes what a newer payload does not carry, and a changed pkg
# identifier makes the new pkg a different package, so without this an upgraded box keeps the OLD
# LaunchDaemons and session agent beside the new ones: two loaders racing to kextload on the same
# trigger, two mt2_linkstated keepers bouncing the same Bluetooth link, forever.
#
# What moved, and who retires it:
#   LaunchDaemon  dev.modernmavericks.voodooinputmavericks             -> here ("pre")
#   LaunchDaemon  dev.modernmavericks.voodooinputmavericks.linkstated  -> here ("pre")
#   LaunchAgent   dev.modernmavericks.voodooinputmavericks.session     -> here ("pre")
#   LaunchAgent   dev.modernmavericks.voodooinputmavericks.updatecheck -> shipyard's agent-load snippet,
#   Trackpad2Updater.app in Application Support/ModernMavericks        -> which the postinstall sources
#   pkg receipt   dev.modernmavericks.voodooinputmavericks             -> here ("post"), forgotten
#   prefs domain  dev.modernmavericks.Trackpad2Updater (per user)      -> here ("post"), COPIED, never moved
#   kext          dev.modernmavericks.VoodooInputMavericks             -> nothing to remove: same file path,
#                 overwritten by the payload. The RESIDENT old driver is left running until the next
#                 boot (never hot-unloaded, see the preinstall), and voodooinputmavericks-run refuses to
#                 load the renamed one beside it until then.
#   Everything else (/usr/local/..., the SIMBL pane, the BezelServices plugin) kept its path and is
#   simply overwritten.
#
# Scoped to Installer's target volume: with none, nothing is known about where the old install lives,
# so nothing is touched -- never an unanchored "/". launchctl only when that volume is the boot volume
# (ROOT empty): it talks to the running system, not to whatever disk the pkg was pointed at. Old names
# spelled out in full: a destructive path must not be one empty variable away from "$ROOT" alone.
# Best-effort throughout: a box that cannot retire the old identity must still get the new version.

PHASE="${1:-}"
TARGET="${2:-}"
[ -n "$TARGET" ] || exit 0
ROOT="${TARGET%/}"

case "$PHASE" in
pre)
    if [ -z "$ROOT" ]; then
        # Stop the old daemons before the payload replaces the binaries they run (same paths as the new
        # ones) -- the preinstall's own unloads name only the new labels.
        launchctl unload /Library/LaunchDaemons/dev.modernmavericks.voodooinputmavericks.plist 2>/dev/null || true
        launchctl unload /Library/LaunchDaemons/dev.modernmavericks.voodooinputmavericks.linkstated.plist 2>/dev/null || true
        # The session agent lives in the console user's GUI session: `launchctl bootout` is 10.11+, and
        # on 10.9 a root script's own launchctl talks to root's session, not the Aqua one, so the
        # fallback runs as the console user (mirrors shipyard's updater/agent-load.in).
        uid=$(stat -f %u /dev/console 2>/dev/null || echo 0)
        user=$(stat -f %Su /dev/console 2>/dev/null || echo root)
        if [ -f /Library/LaunchAgents/dev.modernmavericks.voodooinputmavericks.session.plist ] \
           && [ "${uid:-0}" -gt 0 ] && [ "$user" != root ]; then
            launchctl bootout gui/"$uid" /Library/LaunchAgents/dev.modernmavericks.voodooinputmavericks.session.plist 2>/dev/null \
                || sudo -u "$user" launchctl unload /Library/LaunchAgents/dev.modernmavericks.voodooinputmavericks.session.plist 2>/dev/null \
                || true
        fi
    fi
    # Removing the plists is what keeps them from coming back at the next boot/login.
    rm -f "$ROOT/Library/LaunchDaemons/dev.modernmavericks.voodooinputmavericks.plist" \
          "$ROOT/Library/LaunchDaemons/dev.modernmavericks.voodooinputmavericks.linkstated.plist" \
          "$ROOT/Library/LaunchAgents/dev.modernmavericks.voodooinputmavericks.session.plist" 2>/dev/null \
        || echo "VoodooInputMavericks: could not remove a pre-rename launchd plist; it may run beside the new one until removed" >&2
    ;;
post)
    # The old receipt would otherwise claim these files forever, under a package nothing will update.
    pkgutil --volume "$TARGET" --forget dev.modernmavericks.voodooinputmavericks >/dev/null 2>&1 || true
    # The updater's per-user preferences (the "Check automatically" opt-in, Sparkle's last-check time
    # and skipped version, the pane's update-available hint) are keyed by its bundle id, which moved.
    # COPY each user's old domain to the new name when the new one does not exist yet: never clobber a
    # choice already made under the new identity, and never delete the user's data. A file copy (not
    # `defaults`) so it reaches every account on the target, logged in or not; cp -p keeps the owner
    # and mode. Nothing has read the new domain before this install, so no cfprefsd holds a stale copy.
    for old in "$ROOT"/Users/*/Library/Preferences/dev.modernmavericks.Trackpad2Updater.plist; do
        [ -f "$old" ] || continue
        new="${old%/*}/dev.mavergreen.Trackpad2Updater.plist"
        [ -e "$new" ] && continue
        cp -p "$old" "$new" 2>/dev/null \
            || echo "VoodooInputMavericks: could not carry $old forward; that user's update settings start fresh" >&2
    done
    ;;
*)
    echo "flag-day-migration.sh: unknown phase '$PHASE' (want pre|post)" >&2
    ;;
esac
exit 0
