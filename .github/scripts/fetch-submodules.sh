#!/usr/bin/env bash
# Fetch the submodules an x86_64 build needs, at the commits pinned by the superproject.
# Skips the arm64-only FEX emulator and the NVIDIA libraries (built with WITHOUT_NVIDIA_LIBS=1).
set -euo pipefail

mapfile -t paths < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' \
    | awk '{print $2}' | grep -vxE 'FEX|nvidia-libs/.*')
git submodule update --init --filter=tree:0 --recursive -- "${paths[@]}"
