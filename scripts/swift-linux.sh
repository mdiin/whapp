#!/usr/bin/env bash
# Runs `swift <args>` for AppCore in a Linux container (swift:6.1 + libsqlite3-dev), for working on the
# kit without a Mac. Only the UI-free code builds there: SwiftUI code is behind `#if canImport(SwiftUI)`.
# On a Mac, use scripts/test.sh instead.
#
# Usage: scripts/swift-linux.sh test
# With LEDJER_SWIFT_PATH set to a local ledjer-swift checkout, that checkout is mounted and used.
set -euo pipefail
[ $# -ge 1 ] || { echo "usage: $0 <swift subcommand> [args], e.g. $0 test" >&2; exit 64; }
root="$(cd "$(dirname "$0")/.." && pwd)"
image=appcore-swift-linux
podman image exists "$image" || podman build -q -t "$image" -f "$root/scripts/Containerfile.linux" "$root/scripts"
mounts=(-v "$root/AppCore":/pkg:Z)
envs=()
if [ -n "${LEDJER_SWIFT_PATH:-}" ]; then
  mounts+=(-v "$(cd "$LEDJER_SWIFT_PATH" && pwd)":/ledjer-swift:Z)
  envs+=(-e LEDJER_SWIFT_PATH=/ledjer-swift)
fi
exec podman run --rm --init "${mounts[@]}" "${envs[@]}" -w /pkg "$image" \
  swift "$1" --scratch-path /pkg/.build-linux "${@:2}"
