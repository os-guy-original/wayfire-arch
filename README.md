# wayfire-arch

A small Arch Linux user repo serving a version-matched Wayfire stack over
GitHub Pages. Users add one repo file, import the signing key, and get the
latest **stable** Wayfire builds that are internally consistent.

## What it ships

A matched set built from the highest version tag common to all three
version-locked projects:

- `wayfire`
- `wf-config`
- `wayfire-plugins-extra`

All three are pinned to one target version, which CI resolves from the shared
tag ladder and records in `versions.json`. That file tracks the current target.

`wlroots` comes from Arch's official `extra` repo (the major version Wayfire's
core targets, currently `wlroots0.20`), so it is not rebuilt here.

Why a matched set: Wayfire's three repos do not tag on a clean ladder (Wayfire
has `v0.10.1`, but `wf-config` and `wayfire-plugins-extra` jump `0.10.0 ->
0.11.0`). Picking the highest tag present in ALL of them (`scripts/resolve-versions.sh`)
avoids pairing, say, `wayfire-plugins-extra` `v0.11.2` (which expects a newer
core) against `wayfire` `v0.11.0`. The real lock is the Wayfire ABI date, checked
at plugin load via each plugin's `getWayfireVersion()`; the tag intersection is a
cheap proxy for "released together against the same ABI".

## Use it

One-time owner setup: enable GitHub Pages (Settings -> Pages, serve the default
branch root), publish the signing key as `wayfire-arch.asc` at the repo root (see
`keyring/README.md`), and set `GPG_PRIVATE_KEY` as a repo secret so CI signs the
db (required for `SigLevel = Required`).

Users bootstrap in one line. It fetches the key over HTTPS, writes the single
`[wayfire-arch]` stanza, and syncs:

```
curl -sSL https://os-guy-original.github.io/wayfire-arch/install.sh | sudo sh
sudo pacman -S wayfire wayfire-plugins-extra
```

Manual alternative (no script): import the key, then put the stanza from
`wayfire-arch.conf` near the top of `/etc/pacman.conf`, right after `[options]`
and ABOVE `[system]`/`[world]`/`[galaxy]`/`[extra]`/`[chaotic-aur]`. Repo order
is what decides the source for the same package name, so `wayfire-arch` has to
sit before the repos that ship their own `wayfire`, or `pacman -S wayfire` pulls
theirs (for example `galaxy`'s stale `wayfire-plugins-extra`).

## How CI keeps it fresh

`.github/workflows/update.yml` runs on dispatch or weekly, in a clean
`archlinux` container:

1. `scripts/resolve-versions.sh` computes the common target version.
2. It is compared to `versions.json`; unchanged means no build.
3. Changed packages build in dependency order: `wf-config` -> `wayfire` ->
   `wayfire-plugins-extra`, each installed so the next resolves it.
4. `scripts/update-repo.sh` runs `repo-add` (signed) and emits sha256 sums.
5. New packages, db, and `versions.json` are committed back and served by Pages.

Trigger a run manually: Actions -> update -> Run workflow.

## Layout

```
packages/<name>/PKGBUILD   One PKGBUILD per package (pkgver is bumped by CI)
scripts/                   resolve-versions, build-package, update-repo
x86_64/                    the served pacman repo (db + .pkg.tar.zst)
versions.json              the currently built target version
wayfire-arch.conf          the pacman.conf snippet (goes near the top)
```

## Notes and limits

- Only the base plugin set builds. The four third-party plugins
  (`wayfire-shadows`, `pixdecor`, `filters`, `focus-request`) are pinned to
  `HEAD` upstream and are behind meson options that default to off. Add them as a
  separate track rebuilt whenever the Wayfire ABI moves, not on this version
  schedule.
- A future Wayfire MAJOR bump may need a wlroots version Arch does not ship in
  `extra`. That would require adding a wlroots build. At the current target this
  is a non-issue.
