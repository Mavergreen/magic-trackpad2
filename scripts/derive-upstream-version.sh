#!/bin/sh
# platform: host-agnostic
# Print this product's version: MAVERICKS_VERSION from CMakeLists.txt, its single source of truth.
#
#   scripts/derive-upstream-version.sh      ->   0.5.2
#
# magic-trackpad2 is its OWN upstream (original Mavergreen code, not a port), so it has no
# -mavericks.N axis: its "upstream version" is simply its own semver, hand-bumped in CMakeLists.txt
# and released under the tag v<version>. The pkg name, pkgbuild --version and the updater's
# CFBundleVersion all derive from the same CMake variable, so reading it here -- rather than keeping
# a second copy in an UPSTREAM_VERSION file -- leaves exactly one place to bump.
#
# The family's derive-upstream-version.sh hooks also WRITE an UPSTREAM_VERSION file, for shipyard's
# version.sh/lib.sh. This one only prints: nothing here reads that file (there is no -mavericks.N to
# count), and a gitignored copy of a value that lives in CMakeLists.txt would be one more thing to
# go stale. release.yml's ver step is its caller.
#
# POSIX sh + BSD sed/grep: runs natively on 10.9 as well as in CI.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
v="$(sed -n 's/^[[:space:]]*set(MAVERICKS_VERSION[[:space:]][[:space:]]*"\([^"]*\)").*/\1/p' "$ROOT/CMakeLists.txt" | head -1)"
# x.y.z with an optional pre-release suffix (-pre.1, -rc.1): the shape CMakeLists.txt documents.
printf '%s\n' "$v" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$' \
  || { echo "derive-upstream-version: no MAVERICKS_VERSION x.y.z[-suffix] in $ROOT/CMakeLists.txt (got '$v')" >&2; exit 1; }
printf '%s\n' "$v"
