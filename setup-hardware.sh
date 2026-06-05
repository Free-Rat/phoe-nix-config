#!/usr/bin/env bash
set -euo pipefail

TARGET="./hardware-configuration.nix"

if [ -f /etc/nixos/hardware-configuration.nix ]; then
  cp /etc/nixos/hardware-configuration.nix "$TARGET"
  echo "Copied hardware-configuration.nix from /etc/nixos/"
else
  echo "No existing hardware-configuration.nix found, generating..."
  nixos-generate-config --show-hardware-config > "$TARGET"
  echo "Generated hardware-configuration.nix via nixos-generate-config"
fi

echo "Done: $TARGET"