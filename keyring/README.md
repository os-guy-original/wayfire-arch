# Repo signing key

The served db is signed with a GPG key so users can set `SigLevel = Required`
(see `wayfire-arch.conf`).

## One-time setup by the repo owner

1. Create a key (no passphrase is easiest for CI):

   ```
   gpg --batch --passphrase '' --quick-generate-key 'wayfire-arch <you@example>' default sign 0
   gpg --list-secret-keys --keyid-format LONG   # note the key id
   ```

2. Publish the public part of the key to this dir so users can add it:

   ```
   gpg --export --armor <keyid> > keyring/wayfire-arch.asc
   ```

3. Store the private part as the GitHub secret `GPG_PRIVATE_KEY`:

   ```
   gpg --export-secret-keys --armor <keyid> | gh secret set GPG_PRIVATE_KEY
   ```

When `GPG_PRIVATE_KEY` is set, CI imports it and signs the db. Without it, CI
publishes an unsigned db and users must set `SigLevel = Optional` instead.

## Users

```
sudo pacman-key --add   keyring/wayfire-arch.asc   # after downloading it
sudo pacman-key --lsign-key <keyid>
```

## Published key

The db is signed by this key (already generated and stored as the
`GPG_PRIVATE_KEY` secret):

- Fingerprint: `BE0C41D2CF13C128CBF87666295422637F516A7D`
- Public file: `wayfire-arch.asc` at the repo root (served by Pages)

`install.sh` fetches this `.asc` over HTTPS and imports it, so users do not
need a keyserver.
