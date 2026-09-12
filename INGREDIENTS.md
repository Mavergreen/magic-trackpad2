# Ingredients

Every input baked into the shipped `voodooinputmavericks-<version>.pkg`: where it is pinned, whether
Renovate tracks it, and what a change to it does. magic-trackpad2 is **its own upstream**
(original ModernMavericks code, not a port), so there is no `-mavericks.N` repackage axis. A
release is `v<MAVERICKS_VERSION>`, cut by hand with a `workflow_dispatch` of `release.yml`
(`release=true`). A changed ingredient reaches users only in the next release someone cuts.

| Ingredient | Pinned in | Renovate | On a change |
|---|---|---|---|
| magic-trackpad2 itself (its own upstream) | `MAVERICKS_VERSION` in `CMakeLists.txt` (semver; read by `scripts/derive-upstream-version.sh`) | n/a: bumped by hand, nothing external to track | bump it, optionally add `release-notes/v<version>.md`, dispatch `release.yml` with `release=true` |
| MacOSX10.9 SDK (kext cross-build only) | URL + SHA-256 in shipyard's `scripts/fetch_sdk.sh` | ✅ via `ModernMavericks/shipyard@v1` (the install action) | the next build uses it; the SDK cache is keyed on `fetch_sdk.sh`, and the kext equivalence gate must still pass |
| Sparkle framework (1.27.3, the updater) | shipyard's `scripts/fetch_sparkle_framework.sh`, via `mavericks_add_updater_app()` | ✅ via `shipyard@v1` | the next build uses it |
| Updater host, LaunchAgent, pkg helpers (`stage_updater.sh`, `build_component_pkg.sh`, compat guard) | shipyard, installed by `install@v1` | ✅ via `shipyard@v1` | the next build uses them |
| VoodooInput ABI headers + simulator sources (acidanthera) | vendored in `third_party/VoodooInput/` at `d897813` (see its `PROVENANCE`) | ❌ untrackable by Renovate: vendored verbatim on purpose (they define our wire ABI, so the bytes live in-tree), and a bump means re-vendoring and reviewing the diff, which no manager can do | re-sync by hand as `PROVENANCE` describes, then release |
| Cross toolchain (the `macos-26` runner's Xcode clang) | the runner image, not pinned | ❌ untrackable: no datasource for a hosted runner's Xcode. The kext equivalence gate (`cmake/characterize_build.sh compare` against `dist/characterization/`) and the per-target compat guard make up for it | a runner image change is covered by those gates on every build |

These are release-time inputs rather than ingredients, but they decide what ships:

- **Native kext reference** `dist/characterization/`: the trusted native 10.9.5 build the cross-built
  kext must match. A native build on the 10.9 box rewrites it (kext POST_BUILD). Commit the refresh
  whenever kext sources change, or the next CI build fails the equivalence gate.
- **EdDSA signer** `ed25519-sign`: the latest `ModernMavericks/ed25519` release, fetched by
  shipyard's `sign_and_appcast.sh` when signing. It is not in the pkg, and ed25519 signatures are
  deterministic, so its version does not change the output.
- **Update signing key**: the public half is `ED_PUBKEY` in `tools/CMakeLists.txt` (the
  ModernMavericks org key); the private half is the `SPARKLE_PRIVATE_KEY` secret.

No ingredient is pinned in a file that a dependency bump could edit, so there is no
`repackage-on-ingredient-bump` caller. The shipyard-delivered inputs arrive with whatever release
is cut next.

## Upstream release notes

No upstream release notes: magic-trackpad2 is its own upstream -- original ModernMavericks code,
versioned `vX.Y.Z` with no `-mavericks` axis -- so no release delivers someone else's changes for
its notes to link. The vendored VoodooInput files are an ingredient frozen at a pinned commit, not
an upstream this product repackages.

## Conformance deviations

_None declared._ This product has not adopted `check-artifact-conformance.sh`. Its version scheme
(`vX.Y.Z`, self-upstream) would need a declared deviation from `<upstream>-mavericks.N` when it does.
