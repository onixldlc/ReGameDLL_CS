# ReGameDLL_CS build image — Debian (glibc)
#
# Build from repo root:
#   podman build -f docker/ReGameDLL/Dockerfile -t regamedll:debian .
#
# Produces the Counter-Strike game dll (cs.so) plus the dist configs and the CSSDK
# headers. ReGameDLL_CS is 32-bit x86 only, hence the i386 architecture and the multilib
# toolchain.
#
# glibc, not musl: the engine dlopen()s cs.so, so the two must share a libc, and the
# engine cannot be musl (Valve's closed-source steamclient.so needs glibc's dlmopen).
# See docker/Dockerfile.alpine.
#
# USE_STATIC_LIBSTDC=ON keeps libstdc++/libgcc inside cs.so, so the runtime does not
# need a C++ runtime present.

FROM docker.io/library/debian:12-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386

RUN apt-get update

RUN apt-get install -y --no-install-recommends \
        build-essential \
        gcc-multilib \
        g++-multilib \
        libc6-dev-i386 \
        cmake \
        git

RUN rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Whole context on purpose: regamedll/version/appversion.sh derives the build number from
# `git rev-list` and stamps "+m" when `git ls-files -m` is non-empty, so a partial copy
# would report a dirty tree. Cost: editing docker/* invalidates the compile layers.
# The regamedll/extra/cssdk submodule must be initialised before building.
COPY . /src

RUN git config --global --add safe.directory /src

RUN test -f /src/regamedll/extra/cssdk/dlls/extdll.h

RUN cmake -B build -DUSE_STATIC_LIBSTDC=ON

RUN cmake --build build -j"$(nproc)"

# Lay out artifacts like the CI "Move files" / "Prepare CSSDK" steps
RUN mkdir -p /publish/bin/linux32/cstrike/dlls

RUN mv build/regamedll/cs.so /publish/bin/linux32/cstrike/dlls/cs.so

RUN mv regamedll/version/appversion.h /publish/appversion.h

RUN cp -a dist /publish/dist

RUN mkdir -p /publish/cssdk

RUN cp -a regamedll/extra/cssdk/. /publish/cssdk/

RUN rm -rf /publish/cssdk/.git /publish/cssdk/LICENSE /publish/cssdk/README.md


FROM docker.io/library/debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386

RUN apt-get update

RUN apt-get install -y --no-install-recommends \
        libc6:i386 \
        libstdc++6:i386 \
        file

RUN rm -rf /var/lib/apt/lists/*

COPY --from=builder /publish /opt/regamedll

COPY docker/ReGameDLL/entrypoint.sh /usr/local/bin/entrypoint.sh

COPY docker/ReGameDLL/verify.sh /usr/local/bin/verify.sh

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/verify.sh

# Mount the HLDS tree (the directory containing cstrike/) here
VOLUME ["/opt/hlds"]

WORKDIR /opt/hlds

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["install"]
