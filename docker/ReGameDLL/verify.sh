#!/bin/sh
# Self-check for the built ReGameDLL_CS artifacts: cs.so exists, is a 32-bit
# i386 ELF shared object, the dist files are present, and the CSSDK headers were
# staged. Exits non-zero on the first problem.
set -e

REGAMEDLL_DIR="${REGAMEDLL_DIR:-/opt/regamedll}"
CS_SO="$REGAMEDLL_DIR/bin/linux32/cstrike/dlls/cs.so"

fail=0

echo "[verify] version: $(sed -n 's/.*APP_VERSION "\(.*\)".*/\1/p' "$REGAMEDLL_DIR/appversion.h")"

if [ ! -f "$CS_SO" ]; then
	echo "[verify] MISSING cs.so"
	fail=1
else
	info=$(file -b "$CS_SO")

	if echo "$info" | grep -qE 'ELF 32-bit LSB .*Intel (80386|i386)'; then
		echo "[verify] ok cs.so ($(stat -c %s "$CS_SO") bytes)"
	else
		echo "[verify] NOT A 32-BIT ELF cs.so -- $info"
		fail=1
	fi

	echo "[verify] file says: $info"

	# The engine dlopen()s cs.so, so its libc must match the engine's, and the engine is
	# glibc. A build linked against both libcs loads under neither, so check for that.
	if grep -a -q 'libc\.so\.6' "$CS_SO"; then
		echo "[verify] libc: glibc"
	else
		echo "[verify] libc: not glibc (unexpected for this image)"
		fail=1
	fi

	if grep -a -q 'libc.musl' "$CS_SO"; then
		echo "[verify] MIXED LIBC: cs.so also needs musl"
		fail=1
	fi
fi

for f in delta.lst game.cfg game_init.cfg; do
	if [ -f "$REGAMEDLL_DIR/dist/$f" ]; then
		echo "[verify] ok dist/$f"
	else
		echo "[verify] MISSING dist/$f"
		fail=1
	fi
done

if [ -f "$REGAMEDLL_DIR/cssdk/dlls/extdll.h" ]; then
	echo "[verify] ok cssdk headers"
else
	echo "[verify] MISSING cssdk headers"
	fail=1
fi

if [ "$fail" -ne 0 ]; then
	echo "[verify] FAILED"
	exit 1
fi

echo "[verify] all artifacts present"
