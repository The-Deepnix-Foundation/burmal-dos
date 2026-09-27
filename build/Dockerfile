# Containerized build environment for BURMAL-DOS.
FROM ghcr.io/void-linux/void-glibc-full:latest

ARG BURMAL_MIRROR=https://repo-default.voidlinux.org

RUN xbps-install -SyuR "${BURMAL_MIRROR}/current" xbps \
    && xbps-install -yuR "${BURMAL_MIRROR}/current" \
        bash git make kmod xz lzo qemu-user-arm qemu-user-aarch64 \
        binfmt-support outils dosfstools e2fsprogs

RUN xbps-install -Sy xorriso squashfs-tools

WORKDIR /work
RUN git clone --depth=1 https://github.com/void-linux/void-mklive.git /opt/burmal-builder

COPY . /work/burmal-dos
ENV BURMAL_SRC=/work/burmal-dos
ENV BURMAL_BUILDER=/opt/burmal-builder
ENV BURMAL_REPOSITORY=${BURMAL_MIRROR}/current
ENV OUTDIR=/output

VOLUME ["/output"]
ENTRYPOINT ["/work/burmal-dos/build/build-iso.sh"]
