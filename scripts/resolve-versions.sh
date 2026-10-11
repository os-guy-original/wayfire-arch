#!/usr/bin/env bash
# Resolve the desired stack state: the matched target version plus the commit
# each tag points at.
#
# target = highest version tag present in ALL of {wf-config, wayfire,
# wayfire-plugins-extra}. Their ladders have gaps (wayfire has v0.10.1, but
# wf-config and wayfire-plugins-extra jump 0.10.0 -> 0.11.0), so we take the
# intersection, not the min of each latest.
#
# Diagnostics go to stderr. A single JSON object goes to stdout:
#   {"version":"0.11.0","wf-config":"<sha>","wayfire":"<sha>",...}
# The commit shas are the change signal: the same version with a moved commit
# means the tag was re-cut and the stack must be rebuilt.
set -euo pipefail

repos=(wf-config wayfire wayfire-plugins-extra)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for r in "${repos[@]}"; do
  # comm needs lexicographic (C-locale) order; version order only for the max.
  gh api "repos/WayfireWM/$r/tags" --paginate --jq '.[].name' \
    | sed -E 's/^v//' \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
    | LC_ALL=C sort -u > "$tmp/$r"
done

comm -12 "$tmp/wf-config" "$tmp/wayfire" > "$tmp/c1"
comm -12 "$tmp/c1" "$tmp/wayfire-plugins-extra" > "$tmp/common"

if [[ ! -s "$tmp/common" ]]; then
  echo "ERROR: no common version across ${repos[*]}" >&2
  exit 1
fi

VERSION="$(LC_ALL=C sort -V "$tmp/common" | tail -1)"
echo "Resolved target version: $VERSION" >&2

# Commit a tag points at, following one level of annotated-tag indirection.
tag_commit() {
  local repo="$1" res typ sha
  res="$(gh api "repos/WayfireWM/$repo/git/ref/tags/v$VERSION" --jq '.object.type+":"+.object.sha')"
  typ="${res%%:*}"
  sha="${res##*:}"
  if [[ "$typ" == "tag" ]]; then
    sha="$(gh api "repos/WayfireWM/$repo/git/tags/$sha" --jq '.object.sha')"
  fi
  echo "$sha"
}

printf '{"version":"%s"' "$VERSION"
for r in "${repos[@]}"; do
  printf ',"%s":"%s"' "$r" "$(tag_commit "$r")"
done
printf '}\n'
