# HLbase — HLDS/Counter-Strike game content, fetched by steamcmd at build time.
#
# Build (context is this folder, no repo files are needed):
#   podman build -f docker/HLbase/Dockerfile -t hlbase:debian docker/HLbase
#
# This image holds only game content plus the 32-bit runtime — no engine, no game dll,
# no entrypoint. docker/runner builds FROM it and adds the compiled binaries, so an
# engine or game-dll change rebuilds ~5 MB of layers instead of re-fetching ~900 MB.
# Rebuild this image only when Valve's content changes.
#
# Counter-Strike only: the Half-Life base game under /opt/hlds/valve is pruned down to
# the files cstrike falls back on, so `-game valve` will not work here.

FROM docker.io/library/debian:12-slim AS fetch

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386

RUN apt-get update

# steamcmd is a 32-bit glibc binary and needs the i386 runtime to run at all
RUN apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        tar \
        lib32gcc-s1 \
        lib32stdc++6

RUN rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/steamcmd /opt/hlds

RUN curl -sSL -o /tmp/steamcmd_linux.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz

RUN tar xzf /tmp/steamcmd_linux.tar.gz -C /opt/steamcmd

RUN rm -f /tmp/steamcmd_linux.tar.gz

# Pre-anniversary HLDS (engine build <= 8684) is the ReHLDS-compatible platform, hence
# -beta steam_legacy. steamcmd exits non-zero on some transient states, so the result is
# asserted below instead of relying on its exit code.
RUN /opt/steamcmd/steamcmd.sh +force_install_dir /opt/hlds +login anonymous +app_set_config 90 mod cstrike +app_update 90 -beta steam_legacy validate +quit || true

RUN test -f /opt/hlds/hlds_linux

RUN test -d /opt/hlds/cstrike

# --- pruning ----------------------------------------------------------------------
# Done in this stage on purpose: deleting files in a later layer of the same stage frees
# nothing, the earlier layer still carries them. The final stage copies the pruned tree.
#
# valve/ CANNOT be removed outright -- GoldSrc mods fall back to it. Removing it aborts
# the engine at startup:
#   FATAL ERROR (shutting down): W_LoadWadFile: couldn't load gfx.wad
# and removing just the big WADs aborts it too, because CS maps reference them:
#   FATAL ERROR (shutting down): TEX_InitFromWad: couldn't open halflife.wad
# So every valve/*.wad stays, as do valve/sound, valve/models and valve/sprites, which a
# cstrike server may precache through the fallback. What goes is client-only or
# Half-Life-only content.

# Half-Life single-player maps (~217 MB)
RUN rm -rf /opt/hlds/valve/maps

# intro/outro videos, client only (~61 MB)
RUN rm -rf /opt/hlds/valve/media

# UI localisation and client resources (~26 MB)
RUN rm -rf /opt/hlds/valve/resource

# client map overviews (~21 MB)
RUN rm -rf /opt/hlds/valve/overviews

# client interface graphics; note this is the gfx DIRECTORY, gfx.wad is a file and stays
RUN rm -rf /opt/hlds/valve/gfx

# client-side dlls (~5.7 MB)
RUN rm -rf /opt/hlds/valve/cl_dlls

# hl.so, used only by -game valve (~10 MB)
RUN rm -rf /opt/hlds/valve/dlls

# 64-bit Steam helpers, never run by a 32-bit dedicated server (~51 MB)
RUN rm -rf /opt/hlds/linux64

# HLDS ships glibc libstdc++.so.6 / libgcc_s.so.1 beside the engine and LD_LIBRARY_PATH
# puts that directory first, so they shadow the system i386 ones. ReHLDS is built with
# gcc 12 and needs GLIBCXX_3.4.29; without this the server dies with
#   Error: /opt/hlds/libstdc++.so.6: version `GLIBCXX_3.4.29' not found
#   Unable to load engine, image is corrupt.
RUN rm -f /opt/hlds/libstdc++.so.6 /opt/hlds/libgcc_s.so.1

# HLDS looks for the Steam client library at ~/.steam/sdk32/steamclient.so, and it must
# be STEAMCMD's copy -- linking the one HLDS ships beside the engine makes the engine
# abort with "FATAL ERROR (shutting down): Unable to initialize Steam" and segfault.
# Keep that single file, then drop the rest of steamcmd (~150 MB net) and HLDS's own
# redundant 46 MB copy.
RUN mkdir -p /opt/steamclient

RUN cp /opt/steamcmd/linux32/steamclient.so /opt/steamclient/steamclient.so

RUN rm -rf /opt/steamcmd

# /opt/hlds/steamclient.so is NOT redundant and must stay: the engine also dlopen()s the
# bare name "steamclient.so", resolved through LD_LIBRARY_PATH, and without it Steam init
# fails even with the sdk32 symlink present:
#   dlopen failed trying to load: steamclient.so
#   [S_API FAIL] SteamAPI_Init() failed; unable to locate a running instance of Steam
#   FATAL ERROR (shutting down): Unable to initialize Steam.
# So two copies are kept on purpose (~46 MB + ~48 MB): HLDS's own beside the engine, and
# steamcmd's for the ~/.steam/sdk32 slot, which rejects HLDS's build.


# --- content image ----------------------------------------------------------------
FROM docker.io/library/debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386

RUN apt-get update

# Runtime only: steamcmd, curl and tar stayed behind in the fetch stage.
# ca-certificates is required even though nothing here fetches over HTTPS -- steamclient
# validates Steam's TLS with it, and without it the server logs
#   src/common/opensslconnection.cpp (1636) : unable to load trusted SSL root certificates
# and never reports "Connection to Steam servers successful".
RUN apt-get install -y --no-install-recommends \
        ca-certificates \
        libc6:i386 \
        libstdc++6:i386 \
        file

RUN rm -rf /var/lib/apt/lists/*

COPY --from=fetch /opt/hlds /opt/hlds

COPY --from=fetch /opt/steamclient/steamclient.so /opt/steamclient/steamclient.so

RUN mkdir -p /root/.steam/sdk32

RUN ln -sf /opt/steamclient/steamclient.so /root/.steam/sdk32/steamclient.so

ENV HLDS_DIR=/opt/hlds

WORKDIR /opt/hlds

# No ENTRYPOINT: this is a base image, not a runnable server. See docker/runner.
