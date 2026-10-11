#!/bin/sh
# wayfire-arch bootstrap.
#
#   curl -sSL https://os-guy-original.github.io/wayfire-arch/install.sh | sudo sh
#
# It imports the repo signing key, enables the repo in pacman.conf, and syncs.
# Nothing is hand-copied; the script fetches the key over HTTPS and writes the
# single required stanza itself.
set -eu

BASE_URL="${WAYFIRE_ARCH_URL:-https://os-guy-original.github.io/wayfire-arch}"
KEY_FILE="wayfire-arch.asc"
REPO_NAME="wayfire-arch"
PACMAN_CONF="/etc/pacman.conf"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: curl -sSL $BASE_URL/install.sh | sudo sh" >&2
  exit 1
fi

for tool in curl gpg pacman-key pacman; do
  command -v "$tool" >/dev/null 2>&1 || { echo "missing required tool: $tool" >&2; exit 1; }
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> Fetching signing key"
curl -fsSL "$BASE_URL/$KEY_FILE" -o "$TMP/$KEY_FILE"

FPR="$(gpg --show-keys --with-colons "$TMP/$KEY_FILE" \
  | awk -F: '/^fpr:/{print $10; exit}')"
[ -n "$FPR" ] || { echo "could not read a key from $KEY_FILE" >&2; exit 1; }

echo "==> Importing and locally signing key $FPR"
pacman-key --add "$TMP/$KEY_FILE"
pacman-key --lsign-key "$FPR"

echo "==> Enabling [$REPO_NAME]"
if grep -q "^\[$REPO_NAME\]" "$PACMAN_CONF"; then
  echo "already present in $PACMAN_CONF"
else
  printf '\n[%s]\nServer = %s/$arch\nSigLevel = Required\n' \
    "$REPO_NAME" "$BASE_URL" >> "$PACMAN_CONF"
fi

echo "==> Syncing databases"
pacman -Sy || echo "NOTE: no published db yet, run the repo CI once."

echo "Done. Install with: pacman -S wayfire wayfire-plugins-extra"
