#!/bin/sh
# platform: macOS-only -- launchctl stops the loader and the handoff daemon before the tree is replaced
if [ -z "$ROOT" ]; then
  launchctl unload /Library/LaunchDaemons/dev.mavergreen.voodooinputmavericks.plist 2>/dev/null || true
  launchctl unload /Library/LaunchDaemons/dev.mavergreen.voodooinputmavericks.linkstated.plist 2>/dev/null || true
fi
