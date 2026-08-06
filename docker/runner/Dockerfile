# runner — deployable Counter-Strike server (ReHLDS + ReGameDLL_CS).
#
# Contains only code built from source in these two repos: the ReHLDS engine, the
# ReGameDLL_CS game dll, and HLbase's fetch script. No Valve content, so this image
# is safe to publish. The game content is downloaded into a volume on first start
# by /usr/local/bin/fetch-content.sh -- see docker-compose.yml, which is the
# intended way to run this.
#
# Build (context is this folder, no repo files are needed):
#   cd ../ReHLDS && podman build -f docker/ReHLDS/Dockerfile -t rehlds:latest .
#   podman build -f docker/ReGameDLL/Dockerfile -t regamedll:latest .
#   podman build -f docker/HLbase/Dockerfile    -t hlbase:latest    docker/HLbase
#   podman build -f docker/runner/Dockerfile    -t hlds-server:latest docker/runner
#
# On plain docker the images are not namespaced with localhost/, so pass:
#   --build-arg HLBASE_IMAGE=hlbase:latest \
#   --build-arg ENGINE_IMAGE=rehlds:latest \
#   --build-arg GAMEDLL_IMAGE=regamedll:latest
#
# The three ARGs are turned into named stages below. buildkit does NOT expand
# variables in COPY --from, so `COPY --from=${ENGINE_IMAGE}` fails with
#   variable expansion is not supported for --from, define a new stage with FROM
#   using ARG from global scope as a workaround
# even though buildah/podman accepts it. Naming the stages is that workaround.
#
# Everything is glibc: the engine dlopen()s cs.so so both must share a libc, and
# Valve's closed-source steamclient.so needs glibc's dlmopen().

ARG HLBASE_IMAGE=localhost/hlbase:latest
ARG ENGINE_IMAGE=localhost/rehlds:latest
ARG GAMEDLL_IMAGE=localhost/regamedll:latest

FROM ${HLBASE_IMAGE} AS hlbase
FROM ${ENGINE_IMAGE} AS engine
FROM ${GAMEDLL_IMAGE} AS gamedll

FROM docker.io/library/debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386

RUN apt-get update

# libc6/libstdc++6 i386: the engine and cs.so are 32-bit.
# lib32gcc-s1: steamcmd needs it, and steamcmd runs here now, not at build time.
# curl + tar: used by fetch-content.sh to pull steamcmd.
# ca-certificates: required even though the server itself fetches nothing over
# HTTPS -- steamclient validates Steam's TLS with it, and without it the server
# logs "unable to load trusted SSL root certificates" and never reports
# "Connection to Steam servers successful".
RUN apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        tar \
        file \
        libc6:i386 \
        libstdc++6:i386 \
        lib32gcc-s1

RUN rm -rf /var/lib/apt/lists/*

# The content fetcher, carried by the scratch HLbase image.
COPY --from=hlbase /hlbase/fetch-content.sh /usr/local/bin/fetch-content.sh

# ReHLDS engine binaries: engine_i486.so, hlds_linux, hltv, core/proxy/demoplayer,
# filesystem_stdio, valve/dlls/director.so. Staged under /opt/dist; the entrypoint
# copies them over the content volume on every start, so pulling a newer image and
# restarting is all an engine update takes.
COPY --from=engine /opt/rehlds/bin/linux32/ /opt/dist/engine/

# ReGameDLL_CS game dll and its dist configs (delta.lst, game.cfg, game_init.cfg)
COPY --from=gamedll /opt/regamedll/bin/linux32/cstrike/dlls/cs.so /opt/dist/cstrike/dlls/cs.so

COPY --from=gamedll /opt/regamedll/dist/ /opt/dist/cstrike/

COPY server-entrypoint.sh /usr/local/bin/server-entrypoint.sh

RUN chmod +x /usr/local/bin/server-entrypoint.sh /usr/local/bin/fetch-content.sh

# HLDS default. Do not change this to publish on another port -- map it instead:
#   podman run -p 8222:27015/udp ...
ENV PORT=27015

ENV MAP=de_dust2

ENV MAXPLAYERS=12

# Where the game content lives. Mount a volume here or the ~700 MB download is
# repeated on every container start.
ENV HLDS_DIR=/opt/hlds

# Scratch space for the download. Pointing this at a directory on the volume turns
# the final move into a rename instead of a copy -- see docker-compose.yml.
ENV STAGE_DIR=/tmp/hlds-fetch

VOLUME /opt/hlds

EXPOSE 27015/udp

WORKDIR /opt/hlds

ENTRYPOINT ["/usr/local/bin/server-entrypoint.sh"]
