#!/bin/sh
# platform: host-agnostic
#   usage: check_pane_updater_identity.sh PANE_BINARY SHIPYARD_SCRIPTS PRODUCT
set -eu
pane="$1"; S="$2"; P="$3"
[ -f "$pane" ] || { echo "FAIL: no built pane at $pane"; exit 1; }
id="$(sh "$S/product-name.sh" updater-bundle-id "$P")"
app="/$(sh "$S/product-name.sh" updater-app "$P")"
fail=0
LC_ALL=C grep -a -q -F "$id" "$pane" || { echo "FAIL: the pane does not read $P's updater defaults domain $id"; fail=1; }
LC_ALL=C grep -a -q -F "$app" "$pane" || { echo "FAIL: the pane does not launch $P's updater at $app"; fail=1; }
if LC_ALL=C grep -a -q -F Trackpad2Updater "$pane"; then echo "FAIL: the pane still names the retired Trackpad2Updater"; fail=1; fi
[ "$fail" -eq 0 ] && echo "PASS: the pane reads $id and launches $app"
exit "$fail"
