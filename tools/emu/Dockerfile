# Toolchain for Rail Runner: CPCtelera (development branch) and floooh/chips for the test emulator.
#   docker build -t railrunner-dev tools/emu
#   docker run --rm -v "$PWD":/work/game -w /work/game railrunner-dev make
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential bison flex libboost-dev libfreeimage-dev wget git ca-certificates \
      python3 python3-pil mono-complete texinfo zlib1g-dev clang lld nodejs \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 -b development https://github.com/lronaldo/cpctelera /opt/cpctelera \
 && cd /opt/cpctelera && (yes | ./setup.sh) > /var/log/cpctelera-setup.log 2>&1
ENV CPCT_PATH=/opt/cpctelera/cpctelera
RUN git clone --depth 1 https://github.com/floooh/chips /opt/chips \
 && git clone --depth 1 --filter=blob:none --sparse https://github.com/floooh/chips-test /opt/chips-test \
 && cd /opt/chips-test && git sparse-checkout set examples/roms
WORKDIR /work/game
