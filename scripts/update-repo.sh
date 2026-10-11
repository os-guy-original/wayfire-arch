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

# Sign each package so `SigLevel = Required` can fetch <pkg>.pkg.tar.zst.sig.
# pacman.conf(5): Required demands a per-package signature, not just the db.
if [[ "${REPO_SIGN:-0}" == "1" ]]; then
  for pkg in "$pkgsdir"/*.pkg.tar.zst; do
    gpg --batch --yes --pinentry-mode loopback \
      ${GPGKEY:+--local-user "$GPGKEY"} --detach-sign "$pkg"
  done
fi

# repo-add leaves the db/files entries as symlinks into the .tar.gz files. A
# static host (GitHub Pages) may not follow them, so materialise real files.
find "$pkgsdir" -maxdepth 1 -type l | while read -r link; do
  tgt="$(readlink "$link")"
  rm -f "$link"
  cp -f "$pkgsdir/$tgt" "$link"
done

echo "--- sha256 of published packages ---"
( cd "$pkgsdir" && sha256sum -- *.pkg.tar.zst )