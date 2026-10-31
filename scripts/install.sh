#!/bin/bash
# Builds Ember, replaces /Applications/Ember.app and starts it. A previous
# install goes to the Trash instead of being deleted.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/build-app.sh

DEST=/Applications/Ember.app
if pgrep -xq Ember; then
    # Ember quits cleanly on SIGTERM and puts the colours back.
    pkill -TERM -x Ember
    for _ in $(seq 1 50); do pgrep -xq Ember || break; sleep 0.1; done
    if pgrep -xq Ember; then echo "Ember did not quit; quit it from the menu bar and re-run" >&2; exit 1; fi
fi
if [ -e "$DEST" ]; then
    mv "$DEST" "$HOME/.Trash/Ember-$(date +%Y%m%d-%H%M%S).app"
fi
ditto build/Ember.app "$DEST"
open "$DEST"
echo "installed and started $DEST"
