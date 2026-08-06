#!/bin/sh
# Fetch the HLDS/Counter-Strike game content into HLDS_DIR.
#
# This script is the entire payload of the HLbase image (FROM scratch). It is
# copied into the runner image and executed there on first start, so no Valve
# content is ever baked into a published image -- only the recipe for getting it.
# Each deployer downloads their own copy under their own Steam Subscriber
# Agreement, which is what steamcmd exists for.
#
#   STAGE_DIR   scratch space for the download (default /tmp/hlds-fetch)
#   HLDS_DIR    final location, normally the mounted volume (default /opt/hlds)
#   FORCE_REFETCH=1  re-download even if HLDS_DIR is already populated
#
# Needs curl, tar and the i386 runtime; steamcmd is a 32-bit glibc binary.

set -eu

STAGE_DIR="${STAGE_DIR:-/tmp/hlds-fetch}"
HLDS_DIR="${HLDS_DIR:-/opt/hlds}"
STEAMCMD_URL="${STEAMCMD_URL:-https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz}"

steamcmd_dir="$STAGE_DIR/steamcmd"
content_dir="$STAGE_DIR/hlds"

log() {
	echo "[fetch] $*"
}

if [ -f "$HLDS_DIR/hlds_linux" ] && [ "${FORCE_REFETCH:-0}" != "1" ]; then
	log "content already present in $HLDS_DIR, nothing to do"
	exit 0
fi

log "staging in $STAGE_DIR, target $HLDS_DIR"
rm -rf "$STAGE_DIR"
mkdir -p "$steamcmd_dir" "$content_dir" "$HLDS_DIR"

log "downloading steamcmd"
curl -sSL -o "$STAGE_DIR/steamcmd_linux.tar.gz" "$STEAMCMD_URL"
tar xzf "$STAGE_DIR/steamcmd_linux.tar.gz" -C "$steamcmd_dir"
rm -f "$STAGE_DIR/steamcmd_linux.tar.gz"

# Pre-anniversary HLDS (engine build <= 8684) is the ReHLDS-compatible platform,
# hence -beta steam_legacy. steamcmd exits non-zero on transient states, so the
# result is asserted below instead of trusting its exit code.
log "running app_update 90 (several hundred MB, this takes a while)"
"$steamcmd_dir/steamcmd.sh" \
	+force_install_dir "$content_dir" \
	+login anonymous \
	+app_set_config 90 mod cstrike \
	+app_update 90 -beta steam_legacy validate \
	+quit || true

test -f "$content_dir/hlds_linux" || {
	log "FAILED: hlds_linux missing after app_update"
	exit 1
}
test -d "$content_dir/cstrike" || {
	log "FAILED: cstrike/ missing after app_update"
	exit 1
}

# --- prune ------------------------------------------------------------------
# valve/ CANNOT be removed outright -- GoldSrc mods fall back to it, and the
# engine aborts at startup:
#   FATAL ERROR (shutting down): W_LoadWadFile: couldn't load gfx.wad
# Removing only the big WADs aborts it too, because CS maps reference them:
#   FATAL ERROR (shutting down): TEX_InitFromWad: couldn't open halflife.wad
# So every valve/*.wad stays, as do valve/sound, valve/models and valve/sprites,
# which a cstrike server may precache through the fallback. What goes below is
# client-only or Half-Life-only content.
log "pruning client-only and Half-Life-only content"

# Half-Life single-player maps (~217 MB)
rm -rf "$content_dir/valve/maps"

# intro/outro videos, client only (~61 MB)
rm -rf "$content_dir/valve/media"

# UI localisation and client resources (~26 MB)
rm -rf "$content_dir/valve/resource"

# client map overviews (~21 MB)
rm -rf "$content_dir/valve/overviews"

# client interface graphics -- the gfx DIRECTORY; gfx.wad is a file and stays
rm -rf "$content_dir/valve/gfx"

# client-side dlls (~5.7 MB)
rm -rf "$content_dir/valve/cl_dlls"

# hl.so, used only by -game valve (~10 MB)
rm -rf "$content_dir/valve/dlls"

# 64-bit Steam helpers, never run by a 32-bit dedicated server (~51 MB)
rm -rf "$content_dir/linux64"

# HLDS ships glibc libstdc++.so.6 / libgcc_s.so.1 beside the engine and
# LD_LIBRARY_PATH puts that directory first, so they shadow the system i386 ones.
# ReHLDS is built with gcc 12 and needs GLIBCXX_3.4.29; without this the server
# dies with:
#   Error: libstdc++.so.6: version `GLIBCXX_3.4.29' not found
#   Unable to load engine, image is corrupt.
rm -f "$content_dir/libstdc++.so.6" "$content_dir/libgcc_s.so.1"

# HLDS looks for the Steam client library at ~/.steam/sdk32/steamclient.so and it
# must be STEAMCMD's copy -- linking the one HLDS ships beside the engine makes
# the engine abort with "Unable to initialize Steam" and segfault. Keep that one
# file, then drop the rest of steamcmd.
#
# $content_dir/steamclient.so is NOT redundant and stays: the engine also
# dlopen()s the bare name "steamclient.so" through LD_LIBRARY_PATH, and without
# it Steam init fails even with the sdk32 symlink present:
#   dlopen failed trying to load: steamclient.so
#   FATAL ERROR (shutting down): Unable to initialize Steam.
# Two copies on purpose: HLDS's own beside the engine, and steamcmd's for the
# ~/.steam/sdk32 slot, which rejects HLDS's build.
mkdir -p "$content_dir/.steamclient"
cp "$steamcmd_dir/linux32/steamclient.so" "$content_dir/.steamclient/steamclient.so"
rm -rf "$steamcmd_dir"

# --- move into place --------------------------------------------------------
# A rename is instant and needs no extra space, but only works within one
# filesystem. STAGE_DIR defaults to /tmp, which is usually NOT the volume, so
# fall back to a copy. Point STAGE_DIR at a directory on the volume (see
# docker-compose.yml) to get the cheap path.
stage_fs=$(stat -c %d "$content_dir")
target_fs=$(stat -c %d "$HLDS_DIR")

if [ "$stage_fs" = "$target_fs" ]; then
	log "same filesystem: moving content into $HLDS_DIR"
	for entry in "$content_dir"/* "$content_dir"/.[!.]*; do
		[ -e "$entry" ] || continue
		mv -f "$entry" "$HLDS_DIR/"
	done
else
	log "different filesystem: copying content into $HLDS_DIR"
	cp -a "$content_dir/." "$HLDS_DIR/"
fi

rm -rf "$STAGE_DIR"

test -f "$HLDS_DIR/hlds_linux"
log "content ready in $HLDS_DIR"
