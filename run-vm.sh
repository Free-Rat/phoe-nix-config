#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FLAKE="$SCRIPT_DIR"

echo "Building NixOS VM..."
nix build "$FLAKE#vm" --no-write-lock-file --impure

echo "Starting VM..."
echo "  SSH: ssh -p 2222 user@localhost"
echo "  Login: user / (no password)"
echo ""

"$SCRIPT_DIR/result/bin/run-nixos-vm" "$@"
