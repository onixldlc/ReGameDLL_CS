#!/bin/sh
# Start the ReHLDS + ReGameDLL_CS server.
#
# Three phases:
#   1. if the content volume is empty, run fetch-content.sh (steamcmd, ~700 MB,
#      several minutes -- once per volume, not once per container)
#   2. copy this image's engine and game dll over the content
#   3. exec hlds_linux
#
# Phase 2 runs on every start, so updating the server is: pull a newer image,
# restart. The content is untouched.
#
# Any arguments are passed through to hlds_linux, so
#   podman run ... hlds-server:latest +map cs_office
# works. With no arguments a default de_dust2 setup is used.
set -e

HLDS_DIR="${HLDS_DIR:-/opt/hlds}"
STAGE_DIR="${STAGE_DIR:-/tmp/hlds-fetch}"
PORT="${PORT:-27015}"
MAP="${MAP:-de_dust2}"
MAXPLAYERS="${MAXPLAYERS:-12}"
SV_LAN="${SV_LAN:-0}"
INSECURE="${INSECURE:-0}"

log() {
	echo "[server] $*"
}

# --- phase 1: content -------------------------------------------------------

mkdir -p "$HLDS_DIR"

if [ ! -f "$HLDS_DIR/hlds_linux" ] || [ "${FORCE_REFETCH:-0}" = "1" ]; then
	log "no game content in $HLDS_DIR — fetching (first start only)"
	log "mount a volume at $HLDS_DIR or this repeats on every start"
	STAGE_DIR="$STAGE_DIR" HLDS_DIR="$HLDS_DIR" /usr/local/bin/fetch-content.sh
fi

# --- phase 2: overlay this image's binaries ---------------------------------

log "installing engine and game dll from image"
cp -a /opt/dist/engine/. "$HLDS_DIR/"
mkdir -p "$HLDS_DIR/cstrike"
cp -a /opt/dist/cstrike/. "$HLDS_DIR/cstrike/"

# HLDS resolves the Steam client library at ~/.steam/sdk32/steamclient.so, and it
# must be steamcmd's copy -- the one HLDS ships beside the engine makes the engine
# abort with "FATAL ERROR (shutting down): Unable to initialize Steam" and
# segfault. fetch-content.sh stashed steamcmd's copy for exactly this.
if [ -f "$HLDS_DIR/.steamclient/steamclient.so" ]; then
	mkdir -p "$HOME/.steam/sdk32"
	ln -sf "$HLDS_DIR/.steamclient/steamclient.so" "$HOME/.steam/sdk32/steamclient.so"
else
	log "warning: $HLDS_DIR/.steamclient/steamclient.so missing — Steam init may fail."
	log "         re-run with FORCE_REFETCH=1 to rebuild the content directory."
fi

# --- phase 3: run -----------------------------------------------------------

cd "$HLDS_DIR"

# hlds_linux resolves engine_i486.so and the game dll relative to cwd
LD_LIBRARY_PATH="$HLDS_DIR:$HLDS_DIR/cstrike:$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH

log "engine: $(file -b ./engine_i486.so | cut -d, -f1-2)"
log "game dll: $(file -b ./cstrike/dlls/cs.so | cut -d, -f1-2)"
log "port: $PORT  map: $MAP  maxplayers: $MAXPLAYERS  sv_lan: $SV_LAN"

# -insecure runs the server without VAC. A non-VAC server does not need a Game
# Server Login Token, so this is the way to run publicly without a Steam account.
insecure_flag=""
if [ "$INSECURE" = "1" ]; then
	insecure_flag="-insecure"
fi

if [ $# -gt 0 ]; then
	set -- "$@"
else
	# shellcheck disable=SC2086 # $insecure_flag is intentionally unquoted: empty = no arg
	set -- -game cstrike -port "$PORT" $insecure_flag +sv_lan "$SV_LAN" +maxplayers "$MAXPLAYERS" +map "$MAP"
fi

# A Game Server Login Token makes a public (sv_lan 0) server a validated Steam
# server. Without one, VAC secure mode rejects joining clients with
# "STEAM validation rejected". Get a token for appid 90 at
# https://steamcommunity.com/dev/managegameservers and pass STEAM_ACCOUNT=<token>.
if [ -n "${STEAM_ACCOUNT:-}" ]; then
	log "using Game Server Login Token"
	set -- "$@" +sv_setsteamaccount "$STEAM_ACCOUNT"
elif [ "$INSECURE" = "1" ]; then
	log "VAC disabled (-insecure): no GSLT needed"
elif [ "$SV_LAN" = "0" ]; then
	log "no STEAM_ACCOUNT set: VAC-secure public server without a GSLT, clients may be"
	log "      refused with \"STEAM validation rejected\". Set STEAM_ACCOUNT=<token>,"
	log "      or INSECURE=1 to run without VAC, or SV_LAN=1 for local-only."
fi

log "starting: ./hlds_linux $*"

# "|| status=$?" matters: a bare failing command would trip set -e and skip the retry
status=0
./hlds_linux "$@" || status=$?

if [ "$status" -eq 0 ]; then
	exit 0
fi

log "first start exited $status — retrying once (expected on a fresh content install)"
exec ./hlds_linux "$@"
