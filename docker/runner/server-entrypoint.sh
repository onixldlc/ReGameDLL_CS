#!/bin/sh
# Start the ReHLDS + ReGameDLL_CS server.
#
# Any arguments are passed through to hlds_linux, so
#   podman run ... hlds-server:debian +map cs_office
# works. With no arguments a default de_dust2 listen setup is used.
#
# A fresh steamcmd install reliably fails its first engine start with
# "Unable to initialize Steam" / a missing steam appid file, so the first launch
# is retried once.
set -e

HLDS_DIR="${HLDS_DIR:-/opt/hlds}"
PORT="${PORT:-8222}"
MAP="${MAP:-de_dust2}"
MAXPLAYERS="${MAXPLAYERS:-12}"
SV_LAN="${SV_LAN:-0}"
INSECURE="${INSECURE:-0}"

log() {
	echo "[server] $*"
}

cd "$HLDS_DIR"

# hlds_linux resolves engine_i486.so and the game dll relative to cwd
LD_LIBRARY_PATH="$HLDS_DIR:$HLDS_DIR/cstrike:$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH

log "engine: $(file -b ./engine_i486.so | cut -d, -f1-2)"
log "game dll: $(file -b ./cstrike/dlls/cs.so | cut -d, -f1-2)"
log "port: $PORT  map: $MAP  maxplayers: $MAXPLAYERS  sv_lan: $SV_LAN"

# -insecure runs the server without VAC. A non-VAC server does not need a Game Server
# Login Token, so this is the way to run publicly without a Steam account.
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
if [ -n "$STEAM_ACCOUNT" ]; then
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

log "first start exited $status — retrying once (expected on a fresh steamcmd install)"
exec ./hlds_linux "$@"
