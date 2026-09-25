#   usage: . build/msc.sh
#          Sourced by a Mavergreen product's build scripts: locates shipyard's scripts as
#          $SHIPYARD and exports SHIPYARD_SCRIPTS. In CI, install@v1 has already exported
#          SHIPYARD_SCRIPTS; anywhere else this asks shipyard-cmake -- the only cmake that configures
#          against shipyard -- where find_package(MavericksShipyard) lands, so a CMAKE_PREFIX_PATH
#          dev override moves the scripts together with the modules. About 2 s, exported so children
#          skip it. CANONICAL COPY: shipyard's scripts/templates/msc.sh; conventions check 17
#          requires every product's copy to match it byte for byte, so change it there, not here.
SHIPYARD="${SHIPYARD_SCRIPTS:-}"
if [ ! -d "$SHIPYARD" ]; then
  _msc_probe="$(mktemp -d "${TMPDIR:-/tmp}/shipyard-probe.XXXXXX")"
  printf '%s\n' 'cmake_minimum_required(VERSION 3.16)' 'project(shipyard_probe NONE)' \
    'find_package(MavericksShipyard REQUIRED)' 'message(STATUS "SHIPYARD_DIR=${MavericksShipyard_DIR}")' \
    > "$_msc_probe/CMakeLists.txt"
  # platform: appending /scripts to the substitution directly made a failed probe (no
  #           shipyard-cmake, a refused configure) yield the literal "/scripts" -- an absolute path,
  #           plausible-looking, and the error below would then complain about the wrong thing. So
  #           assign the probe's answer first and append only if there was one.
  _msc_dir="$("$(command -v shipyard-cmake || echo /usr/local/mavergreen/bin/shipyard-cmake)" -S "$_msc_probe" -B "$_msc_probe/b" 2>/dev/null | sed -n 's/^-- SHIPYARD_DIR=//p')"
  if [ -n "$_msc_dir" ]; then SHIPYARD="$_msc_dir/scripts"; fi
  rm -rf "$_msc_probe"; unset _msc_probe _msc_dir
fi
[ -d "$SHIPYARD" ] || { echo "msc.sh: cannot locate shipyard -- install the shipyard pkg (it provides shipyard-cmake), or set SHIPYARD_SCRIPTS" >&2; return 1 2>/dev/null || exit 1; }
SHIPYARD_SCRIPTS="$SHIPYARD"
export SHIPYARD SHIPYARD_SCRIPTS
