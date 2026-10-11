#!/usr/bin/env bash
# Build one package of the matched stack and emit its .pkg.tar.zst.
#
# Version and pkgrel come from versions.json (written by sync-versions.py), so
# all packages of a stack share them. Must run as a non-root user inside the
# build environment.
# Usage: build-package.sh <pkg-dir-name>
set -euo pipefail

pkg="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSIONS_JSON="$ROOT/versions.json"

# Cache downloaded sources and VCS clones outside the repo, otherwise makepkg's
# git clone (e.g. wayfire) lands in packages/<pkg>/wayfire and gets committed.
SRCDEST="$(mktemp -d)"
export SRCDEST

dir="$ROOT/packages/${pkg}"
[[ -f "$dir/PKGBUILD" ]] || { echo "no PKGBUILD in $dir" >&2; exit 1; }

version="$(python -c 'import json,sys;print(json.load(open(sys.argv[1]))["target_version"])' "$VERSIONS_JSON")"
pkgrel="$(python -c 'import json,sys;print(json.load(open(sys.argv[1]))["pkgrel"])' "$VERSIONS_JSON")"

pushd "$dir" >/dev/null

# Pin version/release. The source URL derives from $pkgver, so this also
# re-points the download at the correct tag.
sed -i "s/^pkgver=.*/pkgver=${version}/" PKGBUILD
sed -i "s/^pkgrel=.*/pkgrel=${pkgrel}/" PKGBUILD

# Refresh source checksums from the pinned tag (careful checksum step).
if command -v updpkgsums >/dev/null; then
  updpkgsums
else
  echo "updpkgsums missing, leaving sha256sums=('SKIP') (pacman-contrib provides it)" >&2
fi

# Deps are pre-installed by the workflow, so build without -s: as the rootless
# builder, -s could try to call pacman to resolve a missing dep and fail.
makepkg -f --clean --noconfirm

popd >/dev/null

ls -1 "$dir"/*.pkg.tar.zst
