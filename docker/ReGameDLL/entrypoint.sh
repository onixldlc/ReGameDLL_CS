#!/bin/sh
# ReGameDLL_CS container entrypoint.
#
#   install  (default) copy cs.so + dist/ into the HLDS tree at $HLDS_DIR
#   verify   run the artifact self-check
#   <other>  executed verbatim
#
# There is no "run" command: ReGameDLL_CS is the Counter-Strike game dll only,
# the engine (HLDS/ReHLDS) lives outside this image.
set -e

REGAMEDLL_DIR="${REGAMEDLL_DIR:-/opt/regamedll}"
HLDS_DIR="${HLDS_DIR:-/opt/hlds}"
MOD_DIR="${MOD_DIR:-cstrike}"

log() {
	echo "[regamedll] $*"
}

require_hlds() {
	if [ ! -d "$HLDS_DIR/$MOD_DIR" ]; then
		log "ERROR: $HLDS_DIR/$MOD_DIR not found."
		log "       Mount a steamcmd-installed HLDS tree at $HLDS_DIR (override mod with MOD_DIR)."
		log "       app_set_config 90 mod cstrike; app_update 90 -beta steam_legacy validate"
		exit 1
	fi
}

install_artifacts() {
	require_hlds
	log "version: $(sed -n 's/.*APP_VERSION "\(.*\)".*/\1/p' "$REGAMEDLL_DIR/appversion.h")"

	log "installing cs.so into $HLDS_DIR/$MOD_DIR/dlls"
	mkdir -p "$HLDS_DIR/$MOD_DIR/dlls"
	cp -av "$REGAMEDLL_DIR/bin/linux32/cstrike/dlls/cs.so" "$HLDS_DIR/$MOD_DIR/dlls/cs.so"

	log "installing dist files into $HLDS_DIR/$MOD_DIR"
	cp -av "$REGAMEDLL_DIR/dist/." "$HLDS_DIR/$MOD_DIR/"

	log "install done"
}

cmd="${1:-install}"
[ $# -gt 0 ] && shift

case "$cmd" in
	install)
		install_artifacts
		;;
	verify)
		exec /usr/local/bin/verify.sh
		;;
	*)
		exec "$cmd" "$@"
		;;
esac
