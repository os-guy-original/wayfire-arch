#!/usr/bin/env bash
# CI step 5/6: assemble the served pacman db (optionally signed) and emit sha256.
# Usage: update-repo.sh <pkgs-dir> [repo-name]
set -euo pipefail

pkgsdir="${1:-x86_64}"
name="${2:-wayfire-arch}"

mkdir -p "$pkgsdir"

sign_args=()
if [[ "${REPO_SIGN:-0}" == "1" ]]; then
  sign_args=(--sign)
  echo "Signing repo db with the imported GPG key."
else
  echo "REPO_SIGN not set, building an unsigned db (SigLevel should be Optional)."
fi

# Remove the existing db so removed packages drop out, then add everything.
rm -f "$pkgsdir/$name".db "$pkgsdir/$name".db.* "$pkgsdir/$name".files "$pkgsdir/$name".files.*
repo-add "${sign_args[@]}" "$pkgsdir/$name.db.tar.gz" "$pkgsdir"/*.pkg.tar.zst

echo "--- sha256 of published packages ---"
( cd "$pkgsdir" && sha256sum -- *.pkg.tar.zst )