#!/bin/sh
# platform: macOS-only -- kextstat and launchctl start the driver loader and the handoff daemon
_rc=0
_t2="$ROOT/usr/local/mavergreen/trackpad2"
_var="$ROOT/usr/local/mavergreen/var/trackpad2"
_trigger="$_var/session.trigger"
chown -R root:wheel "$_t2/lib/VoodooInputMavericks.kext" || _rc=1
chmod -R 755 "$_t2/lib/VoodooInputMavericks.kext" || _rc=1
mkdir -p "$_var" || _rc=1
echo ok > "$_var/boot.state" || _rc=1
if [ ! -e "$_trigger" ]; then : > "$_trigger" || _rc=1; fi
chmod 666 "$_trigger" || _rc=1
if [ -z "$ROOT" ]; then
  launchctl unload /Library/LaunchDaemons/dev.mavergreen.voodooinputmavericks.plist 2>/dev/null || true
  launchctl load -w /Library/LaunchDaemons/dev.mavergreen.voodooinputmavericks.plist || _rc=1
  if kextstat 2>/dev/null | grep -q VoodooInputMavericks; then
    echo "VoodooInputMavericks: update staged; restart to finish (the new driver loads at next boot)."
  else
    touch "$_trigger"
    ( sleep 3; "$_t2/libexec/mt2_linkstated" --bounce-once >/dev/null 2>&1 ) &
  fi
  launchctl unload /Library/LaunchDaemons/dev.mavergreen.voodooinputmavericks.linkstated.plist 2>/dev/null || true
  launchctl load -w /Library/LaunchDaemons/dev.mavergreen.voodooinputmavericks.linkstated.plist 2>/dev/null || true
fi
if [ ! -d "$ROOT/Library/Application Support/SIMBL/SIMBLAgent.app" ]; then
  echo "VoodooInputMavericks: the trackpad works now. For the Trackpad preference pane (settings, battery,"
  echo "rename), install SIMBL, then relaunch System Preferences:"
  echo "  https://mavericksforever.com/downloads/SIMBL.pkg"
fi
_bezel_src="$ROOT/Library/Application Support/Apple/BezelServices/AppleBluetoothMultitouch.plugin/Contents/Resources"
_bezel_dst="$ROOT/Library/Application Support/Apple/BezelServices/MavericksMultitouch.plugin/Contents/Resources"
mkdir -p "$_bezel_dst"
cp "$_bezel_src/BtTrackpad.pdf" "$_bezel_dst/MavericksTrackpad.pdf" 2>/dev/null || true
cp "$_bezel_src/MagicTrackpad.icns" "$_bezel_dst/MavericksTrackpad.icns" 2>/dev/null || true
_upd_icon="$ROOT/Library/Application Support/Mavergreen/trackpad2-updater.app/Contents/Resources/Trackpad2Updater.icns"
if [ -f "$_upd_icon" ]; then cp "$_bezel_src/MagicTrackpad.icns" "$_upd_icon" 2>/dev/null || true; fi
[ "$_rc" -eq 0 ]
