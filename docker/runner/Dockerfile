# runner — deployable Counter-Strike server.
#
# Combines the HLbase content image with the two compiled artifacts and starts the
# server. Build (context is this folder, no repo files are needed):
#
#   cd ../ReHLDS && podman build -f docker/ReHLDS/Dockerfile -t rehlds:debian .
#   podman build -f docker/ReGameDLL/Dockerfile -t regamedll:debian .
#   podman build -f docker/HLbase/Dockerfile    -t hlbase:debian    docker/HLbase
#   podman build -f docker/runner/Dockerfile    -t hlds-server:debian docker/runner
#
# On plain docker the images are not namespaced with localhost/, so pass:
#   --build-arg HLBASE_IMAGE=hlbase:debian \
#   --build-arg ENGINE_IMAGE=rehlds:debian \
#   --build-arg GAMEDLL_IMAGE=regamedll:debian
#
# FROM the base rather than COPY --from it: the ~500 MB of content layers are then shared
# instead of duplicated, and rebuilding after an engine or game-dll change only rewrites
# the few MB on top -- seconds, with no content re-copy. HLbase stays an independent
# image. If it ever needs to be pure data (FROM scratch, no OS), switch the FROM below to
# debian:12-slim and add:
#   COPY --from=${HLBASE_IMAGE} /opt/hlds /opt/hlds
# at the cost of duplicating the content and re-copying it on every rebuild.
#
# Everything is glibc: the engine dlopen()s cs.so so both must share a libc, and Valve's
# closed-source steamclient.so needs glibc's dlmopen().

ARG HLBASE_IMAGE=localhost/hlbase:debian
ARG ENGINE_IMAGE=localhost/rehlds:debian
ARG GAMEDLL_IMAGE=localhost/regamedll:debian

FROM ${HLBASE_IMAGE}

# ReHLDS engine binaries: engine_i486.so, hlds_linux, hltv, core/proxy/demoplayer,
# filesystem_stdio, valve/dlls/director.so
ARG ENGINE_IMAGE

COPY --from=${ENGINE_IMAGE} /opt/rehlds/bin/linux32/ /opt/hlds/

# ReGameDLL_CS game dll and its dist configs (delta.lst, game.cfg, game_init.cfg)
ARG GAMEDLL_IMAGE

COPY --from=${GAMEDLL_IMAGE} /opt/regamedll/bin/linux32/cstrike/dlls/cs.so /opt/hlds/cstrike/dlls/cs.so

COPY --from=${GAMEDLL_IMAGE} /opt/regamedll/dist/ /opt/hlds/cstrike/

COPY server-entrypoint.sh /usr/local/bin/server-entrypoint.sh

RUN chmod +x /usr/local/bin/server-entrypoint.sh

# HLDS default. Do not change this to publish on another port -- map it instead:
#   podman run -p 8222:27015/udp ...
ENV PORT=27015

ENV MAP=de_dust2

ENV MAXPLAYERS=12

EXPOSE 27015/udp

WORKDIR /opt/hlds

ENTRYPOINT ["/usr/local/bin/server-entrypoint.sh"]
