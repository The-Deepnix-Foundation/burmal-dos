#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p out
chmod 777 out 2>/dev/null || true
OLD=$(docker ps -q --filter ancestor=burmal-dos-build 2>/dev/null || true)
if [ -n "$OLD" ]; then
    echo "Остановка зависших контейнеров"
    docker kill $OLD >/dev/null 2>&1 || true
fi

echo "Docker образ."
docker build --platform linux/amd64 \
    --build-arg BURMAL_MIRROR="${BURMAL_MIRROR:-https://repo-default.voidlinux.org}" \
    -t burmal-dos-build -f build/Dockerfile .

echo "Сборка iso внутри контейнера"
docker run --rm --privileged \
    --device /dev/loop-control:/dev/loop-control \
    --device /dev/loop0:/dev/loop0 \
    --platform linux/amd64 -v "$PWD/out:/output" burmal-dos-build

echo
echo "iso собран"
ls -la out/
