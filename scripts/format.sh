#!/bin/bash
# Formats every Swift file in place with the repo's .swift-format settings.
# Pass --check to change nothing and fail if anything needs formatting (CI does).
set -euo pipefail
cd "$(dirname "$0")/.."
FILES=(Package.swift Sources Tests scripts/*.swift)
if [ "${1:-}" = "--check" ]; then
    exec swift format lint --strict --recursive "${FILES[@]}"
fi
exec swift format format --in-place --recursive "${FILES[@]}"
