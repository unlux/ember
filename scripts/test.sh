#!/bin/bash
# Runs the unit tests. With only the Command Line Tools installed (no Xcode),
# SwiftPM finds the Testing module but not its macro plugin, so point at it.
set -euo pipefail
cd "$(dirname "$0")/.."
PLUGINS=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
if [ "$(xcode-select -p)" = /Library/Developer/CommandLineTools ] && [ -d "$PLUGINS" ]; then
    exec swift test -Xswiftc -plugin-path -Xswiftc "$PLUGINS" "$@"
fi
exec swift test "$@"
