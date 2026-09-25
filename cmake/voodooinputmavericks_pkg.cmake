# cmake/voodooinputmavericks_pkg.cmake — the product archive: stage the trackpad2 tree and the OS-dictated
# files, then stage_product.sh, build_component_pkg.sh and set_install_floor.sh.
set(PKGROOT ${CMAKE_BINARY_DIR}/pkgroot)
# Version stamped into the pkg name + component: the single source of truth,
# MAVERICKS_VERSION (full string incl. any pre-release suffix). Still overridable via
# -DMAVERICKS_PKG_VERSION for one-off builds.
if(NOT MAVERICKS_PKG_VERSION)
  set(MAVERICKS_PKG_VERSION ${MAVERICKS_VERSION})
endif()
set(PKG_OUT ${CMAKE_BINARY_DIR}/voodooinputmavericks-${MAVERICKS_PKG_VERSION}.pkg)
set(PKG_SCRIPTS ${CMAKE_BINARY_DIR}/pkg-scripts)
set(T2 ${PKGROOT}/usr/local/mavergreen/trackpad2)
set(SIMBL_PLUGINS "${PKGROOT}/Library/Application Support/SIMBL/Plugins")
set(BEZEL "${PKGROOT}/Library/Application Support/Apple/BezelServices")
set(PKG_COMPONENT_DIR ${CMAKE_BINARY_DIR}/pkg-component)
add_custom_target(pkg
  COMMAND ${CMAKE_COMMAND} -E remove_directory ${PKGROOT}
  COMMAND ${CMAKE_COMMAND} -E remove_directory ${PKG_SCRIPTS}
  COMMAND ${CMAKE_COMMAND} -E remove_directory ${PKG_COMPONENT_DIR}
  COMMAND ${CMAKE_COMMAND} -E make_directory ${T2}/lib ${T2}/sbin ${T2}/libexec
          ${PKGROOT}/Library/LaunchDaemons ${PKGROOT}/Library/LaunchAgents ${SIMBL_PLUGINS} ${BEZEL} ${PKG_COMPONENT_DIR}
  COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_BINARY_DIR}/VoodooInputMavericks.kext ${T2}/lib/VoodooInputMavericks.kext
  COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/dist/voodooinputmavericks-run ${T2}/sbin/
  COMMAND chmod +x ${T2}/sbin/voodooinputmavericks-run
  COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/sbin/mt2_reenumerate ${T2}/libexec/
  COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/sbin/mt2_linkstated ${T2}/libexec/
  COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/dist/dev.mavergreen.voodooinputmavericks.plist ${PKGROOT}/Library/LaunchDaemons/
  COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/dist/dev.mavergreen.voodooinputmavericks.linkstated.plist ${PKGROOT}/Library/LaunchDaemons/
  COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/dist/dev.mavergreen.voodooinputmavericks.session.plist ${PKGROOT}/Library/LaunchAgents/
  COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_BINARY_DIR}/VoodooInputMavericksPane.bundle "${SIMBL_PLUGINS}/VoodooInputMavericksPane.bundle"
  COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_SOURCE_DIR}/dist/MavericksMultitouch.plugin "${BEZEL}/MavericksMultitouch.plugin"
  COMMAND sh ${MavericksShipyard_SCRIPTS}/stage_product.sh
          --stage ${PKGROOT} --product trackpad2 --name "Mavericks Trackpad 2"
          --version ${MAVERICKS_PKG_VERSION}
          --updater-app ${CMAKE_BINARY_DIR}/trackpad2-updater.app
          --preinstall-hook ${CMAKE_SOURCE_DIR}/dist/hooks/preinstall.sh
          --postinstall-hook ${CMAKE_SOURCE_DIR}/dist/hooks/postinstall.sh
          --scripts-out ${PKG_SCRIPTS}
  COMMAND sh ${MavericksShipyard_SCRIPTS}/build_component_pkg.sh
          --root ${PKGROOT} --scripts ${PKG_SCRIPTS}
          --identifier dev.mavergreen.voodooinputmavericks --version ${MAVERICKS_PKG_VERSION}
          --install-location / --out ${PKG_COMPONENT_DIR}/voodooinputmavericks-component.pkg
  COMMAND sh ${MavericksShipyard_SCRIPTS}/set_install_floor.sh
          --identifier dev.mavergreen.voodooinputmavericks --title "Mavericks Trackpad 2"
          --component ${PKG_COMPONENT_DIR}/voodooinputmavericks-component.pkg --out ${PKG_OUT}
          --resources ${CMAKE_SOURCE_DIR}/dist/resources --welcome Welcome.html --conclusion Conclusion.html
          --require-scripts
  COMMAND sh ${CMAKE_SOURCE_DIR}/cmake/check_pkg_payload.sh ${PKG_OUT}
  COMMAND sh ${MavericksShipyard_SCRIPTS}/assert_pkg_installs_in_place.sh ${PKG_OUT}
  DEPENDS kext mt2_reenumerate VoodooInputMavericksPane_simbl mt2_linkstated trackpad2-updater
  COMMENT "Building ${PKG_OUT} (base first, 10.9.5 floor, conclusion pane)")

# Dev "install exactly what a user gets": build the release .pkg and install it locally through the SAME
# installer flow (scripts, component versions, BOTH prefpane loaders) a real user runs. Use THIS during dev
# instead of hand-copying individual pieces — that divergence is what left a STALE SIMBL payload (watching
# retired classes) running on-device while the repo source was current (2026-07-20). Requires sudo (the pkg
# writes /usr/local + /Library); the target owns its own privilege, mirroring kext-load.
add_custom_target(install-pkg
  COMMAND sudo installer -pkg ${PKG_OUT} -target /
  DEPENDS pkg
  COMMENT "Installing ${PKG_OUT} to / (release-identical local install)")
