#!/usr/bin/env bash
# The quality checks on macOS, always on the same simulator (snapshot images depend on it).
#
#   scripts/test.sh                          AppCore's tests (incl. snapshots), then a build of the app
#   scripts/test.sh --only AppCoreTests/X    only the tests of suite X (Swift Testing: the type's name)
#   scripts/test.sh --app                    only the build of the app
#
# SIMULATOR overrides the simulator's name (default "iPhone 16"). If it isn't installed, the available
# ones are listed: pick one, and record it in the README, as reference images must be recorded on it.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
simulator="${SIMULATOR:-iPhone 16}"
destination="platform=iOS Simulator,name=$simulator"

if ! xcrun simctl list devices available | grep -q "    $simulator ("; then
  echo "Simulator \"$simulator\" is not available. Available devices:" >&2
  xcrun simctl list devices available >&2
  exit 1
fi

only=()
tests=yes
app=yes
while [ $# -gt 0 ]; do
  case "$1" in
    --only) only+=("-only-testing:$2"); app=no; shift 2 ;;
    --app) tests=no; shift ;;
    *) echo "unknown argument: $1" >&2; exit 64 ;;
  esac
done

if [ "$tests" = yes ]; then
  cd "$root/AppCore"
  # A package with one library gets a scheme named after it; with more, the tests are in "<name>-Package".
  scheme=AppCore
  if xcodebuild -list 2>/dev/null | grep -q "AppCore-Package"; then scheme=AppCore-Package; fi
  xcodebuild test -scheme "$scheme" -destination "$destination" -skipMacroValidation -quiet "${only[@]}"
fi

if [ "$app" = yes ]; then
  cd "$root"
  xcodebuild build -project App.xcodeproj -scheme App -destination "$destination" -skipMacroValidation -quiet
fi
