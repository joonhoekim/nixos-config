# nixos-config

> 한국어: [README.md](README.md)

Personal Nix configuration for macOS (nix-darwin + home-manager) and NixOS.

The darwin configurations are keyed by **architecture**, not hostname:
`aarch64-darwin` (Apple Silicon) and `x86_64-darwin` (Intel). Use that name as
the flake target — e.g. `.#aarch64-darwin`.

The NixOS configurations are keyed by **hostname** — `mn56`, `intel` and
`galaxy-chromebook-1` (all `x86_64-linux`). Use that name as the flake target —
e.g. `.#mn56`. See [NixOS — first build](#nixos--first-build-on-a-new-machine)
for the machine-specific setup.

All three hosts run **GNOME on Wayland** (GDM).

## Bootstrap — macOS (first run on a new machine)

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

## NixOS — first build on a new machine

The flakes-enabling step above applies on NixOS too (the first flake command
needs `--extra-experimental-features 'nix-command flakes'`). On top of that,
three things are machine-specific and must be set **before** the first build:

1. **Provide this machine's hardware config.** `mn56` and `intel` ship a
   *placeholder* `hosts/nixos/<host>/hardware-configuration.nix` — committed so
   the tree resolves, but deliberately missing `fileSystems` so an un-replaced
   placeholder fails loudly instead of building an unbootable system. Generate
   the real one on the target machine and overwrite it (`galaxy-chromebook-1`
   is an already-installed machine and carries its real one):

   ```sh
   # on an existing NixOS install:
   cp /etc/nixos/hardware-configuration.nix hosts/nixos/mn56/hardware-configuration.nix
   # …or from a live hardware scan:
   sudo nixos-generate-config --show-hardware-config > hosts/nixos/mn56/hardware-configuration.nix
   git add hosts/nixos/mn56/hardware-configuration.nix
   ```

   It pins your root/boot filesystems, swap, initrd modules, and CPU microcode,
   so it can't be shared between machines.

2. **Pick the host.** Hosts are keyed by hostname (`mn56`, `intel`,
   `galaxy-chromebook-1`). To add another, create `hosts/nixos/<name>/`
   (importing `../common.nix` plus its own `hardware-configuration.nix`) and
   register it in `flake.nix`'s `mkNixosHost` list. Keep the flake attribute
   name and `networking.hostName` identical so `build-switch` finds the host
   on its own.

3. **Decide how you SSH in.** `hosts/nixos/common.nix` enables `openssh` without
   declaring any authorized key, so access is by account password (set it with
   `passwd`). For key auth, add your public key to
   `users.users.<user>.openssh.authorizedKeys.keys`.

Then build:

```sh
sudo nixos-rebuild switch --flake .#mn56      # or .#intel, .#galaxy-chromebook-1
# once flakes are enabled and the hostname matches a host: nix run .#build-switch
```

> `nix flake check` evaluates the NixOS hosts too, so it fails at the
> `fileSystems` assertion until a real hardware-configuration.nix is in place.
> That's expected and doesn't affect `build-switch`.

## Daily usage

The app scripts (`apps/`) are shared across platforms and detect macOS vs NixOS
at runtime, so the same command works on either:

```sh
nix run .#build-switch          # build the new generation and activate it
```

- **macOS** → builds + activates `darwinConfigurations.<arch>` (e.g. `aarch64-darwin`).
- **NixOS** → activates `nixosConfigurations.<hostname>`. The host is taken from
  `hostname`; override it before the first switch with
  `nix run .#build-switch -- --host mn56` (or `--host intel`).
- **Don't prefix it with `sudo`.** The script builds as your user, then calls
  `sudo` only for the activation step. Running the whole thing as root breaks
  git ownership checks on the repo.
- Extra flags pass through, e.g. `nix run .#build-switch -- --show-trace`.

To call the rebuild tools directly instead, name the config explicitly (a bare
`.#` resolves by hostname, which won't match the arch-named darwin configs):

```sh
sudo darwin-rebuild switch --flake .#aarch64-darwin   # macOS
sudo nixos-rebuild  switch --flake .#mn56              # NixOS
```

## Other flake apps

```sh
nix run .#build               # build only, no switch (verify it evaluates)
nix run .#rollback            # roll back to a previous generation
nix run .#clean               # garbage-collect old generations (default 7d; e.g. `-- 14d`)
```
