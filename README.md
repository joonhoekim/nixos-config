# nixos-config

Personal Nix configuration for macOS (nix-darwin + home-manager) and NixOS.

The darwin configurations are keyed by **architecture**, not hostname:
`aarch64-darwin` (Apple Silicon) and `x86_64-darwin` (Intel). Use that name as
the flake target — e.g. `.#aarch64-darwin`.

## Bootstrap — first time on a new machine

Applying this config enables `nix-command` and `flakes` system-wide (via
`nix.extraOptions` → `/etc/nix/nix.conf`). But there's a chicken-and-egg
problem: to *apply* the config you must run a flake command, which already
needs flakes enabled. So the **very first** invocation needs flakes turned on
by hand. Pick one of the options below — you only do this once per machine.

1. **Install Nix** (official multi-user installer):

   ```sh
   sh <(curl -L https://nixos.org/nix/install)
   ```

2. **Enable flakes for the first run.** Any one of:

   - Add one line to `/etc/nix/nix.conf` (the method I use):

     ```sh
     echo 'experimental-features = nix-command flakes' | sudo tee -a /etc/nix/nix.conf
     # then restart the nix-daemon (or just open a new shell):
     sudo launchctl kickstart -k system/org.nixos.nix-daemon
     ```

   - …or set it for a single command, no file editing:

     ```sh
     export NIX_CONFIG="extra-experimental-features = nix-command flakes"
     ```

   - …or pass it inline on the first command only:

     ```sh
     nix run --extra-experimental-features 'nix-command flakes' .#build-switch
     ```

3. **Build and switch:**

   ```sh
   nix run .#build-switch
   ```

After the first switch, nix-darwin manages `/etc/nix/nix.conf` itself (it
becomes a symlink into `/etc/static/nix/`) and keeps flakes enabled, so the
one-time step above is never needed again on this machine.

> Tip: the [Determinate Systems installer](https://install.determinate.systems)
> enables flakes by default, which skips step 2 entirely. I use the official
> installer, hence the manual step.

## Daily usage

```sh
nix run .#build-switch          # build the new generation and activate it
```

- **Don't prefix it with `sudo`.** The script builds as your user, then calls
  `sudo` only for the activation step. Running the whole thing as root breaks
  git ownership checks on the repo.
- Extra flags pass through, e.g. `nix run .#build-switch -- --show-trace`.

To use `darwin-rebuild` directly instead, name the config explicitly (a bare
`.#` resolves by hostname, which won't match the arch-named configs here):

```sh
sudo darwin-rebuild switch --flake .#aarch64-darwin
```

## Other flake apps

```sh
nix run .#build       # build only, no switch
nix run .#rollback    # roll back to the previous generation
nix run .#clean       # garbage-collect old generations
nix run .#apply       # templating helper (substitutes user/name placeholders)
```
