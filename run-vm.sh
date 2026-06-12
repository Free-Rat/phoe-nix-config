#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FLAKE="$SCRIPT_DIR"
RESULT_LINK="$SCRIPT_DIR/result"

echo "Building NixOS VM..."
rm -f "$RESULT_LINK"
nix build "$FLAKE#vm" --no-write-lock-file --impure --out-link "$RESULT_LINK"

echo "Starting VM..."
echo "  SSH: ssh -p 2222 user@localhost"
echo "  Login: user / (no password)"
echo ""

"$RESULT_LINK/bin/run-nixos-vm" "$@"
