#!/usr/bin/env python3
"""Compare the desired stack state against what is already built.

Usage: sync-versions.py <desired.json> <versions.json>

desired.json holds the resolved target version plus each package's source
commit (produced by resolve-versions.sh). versions.json is the state that has
actually been built and published.

Rules:
  * version changed            -> pkgrel resets to 1
  * version same, commit moved -> pkgrel += 1 (tag re-cut, so users upgrade)
  * nothing changed            -> changed=false, nothing to do

On any change the new state is written to versions.json and two lines are
printed for GitHub step outputs: changed=true|false and TARGET=<version>.
"""
import json
import sys

REPOS = ["wf-config", "wayfire", "wayfire-plugins-extra"]


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: sync-versions.py <desired.json> <versions.json>", file=sys.stderr)
        return 2

    with open(sys.argv[1]) as f:
        desired = json.load(f)
    versions_path = sys.argv[2]
    with open(versions_path) as f:
        current = json.load(f)

    version = desired["version"]
    version_changed = version != current.get("target_version")
    cur_sources = current.get("sources", {})
    sources_changed = any(cur_sources.get(r) != desired[r] for r in REPOS)

    if not version_changed and not sources_changed:
        print("changed=false")
        print(f"TARGET={version}")
        return 0

    if version_changed:
        pkgrel = 1
    else:
        pkgrel = int(current.get("pkgrel", 0)) + 1

    new_state = {
        "target_version": version,
        "pkgrel": pkgrel,
        "sources": {r: desired[r] for r in REPOS},
    }
    with open(versions_path, "w") as f:
        json.dump(new_state, f, indent=2)
        f.write("\n")

    print("changed=true")
    print(f"TARGET={version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
