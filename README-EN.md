# nixos-config

> 한국어: [README.md](README.md)

Personal Nix configuration for macOS (nix-darwin + home-manager) and NixOS.

The darwin configurations are keyed by **architecture**, not hostname:
`aarch64-darwin` (Apple Silicon) and `x86_64-darwin` (Intel). Use that name as
the flake target — e.g. `.#aarch64-darwin`.

The NixOS configurations are keyed by **hostname** — `mn56` and
`galaxy-chromebook-1` (both `x86_64-linux`). Use that name as the flake target —
e.g. `.#mn56`. A host directory only exists for a machine that actually exists,
since it needs that machine's generated `hardware-configuration.nix`. See
[NixOS — first build](#nixos--first-build-on-a-new-machine) for the
machine-specific setup.

Both hosts offer two sessions at the greetd/tuigreet greeter: **niri**
(scrollable tiling plus a Quickshell desktop shell, the default) and **GNOME on
Wayland** (the fallback). The shell is DankMaterialShell; see
[modules/nixos/niri](modules/nixos/niri).

niri's and DMS's *settings* are not managed by Nix. They are ordinary writable
files under `~/.config`, so niri hot-reloads on save and the DMS settings GUI
works normally. [modules/nixos/niri/rice](modules/nixos/niri/rice) is a backup
and a seed for a fresh machine (copied in only when the file is missing);
`apps/rice-save` snapshots the live config back into it.

Looks are split into profiles and switching applies instantly — no restart, no
rebuild:

```sh
apps/rice-switch              # current profile + list      (Mod+Shift+P = next)
apps/rice-switch frosted      # amoled | frosted | matugen
apps/rice-wall mountain       # recursive search of ~/Pictures/Wallpapers  (Mod+Shift+W)
apps/rice-wall --pick         # pick one through fuzzel                    (Mod+Ctrl+W)
```

A profile is two pieces (`niri.kdl` / `dms.json`). Only the
DMS piece is an overlay rather than a whole-file swap — `settings.json` also
holds machine state that has nothing to do with the look, and replacing it
wholesale would take that with it. The `matugen` profile derives its palette
from the wallpaper and pushes it to the shell, niri's borders and the terminal
in one go.

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

1. **Provide this machine's hardware config.** Every registered host (`mn56`,
   `galaxy-chromebook-1`) carries the real
   `hosts/nixos/<host>/hardware-configuration.nix` generated on that machine.
   When adding a new machine, produce this file **before** creating the host
   directory — committing an empty placeholder only breaks evaluation at the
   `fileSystems` assertion and buys nothing:

   ```sh
   # on an existing NixOS install:
   cp /etc/nixos/hardware-configuration.nix hosts/nixos/mn56/hardware-configuration.nix
   # …or from a live hardware scan:
   sudo nixos-generate-config --show-hardware-config > hosts/nixos/mn56/hardware-configuration.nix
   git add hosts/nixos/mn56/hardware-configuration.nix
   ```

   It pins your root/boot filesystems, swap, initrd modules, and CPU microcode,
   so it can't be shared between machines.

2. **Pick the host.** Hosts are keyed by hostname (`mn56`,
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
sudo nixos-rebuild switch --flake .#mn56      # or .#galaxy-chromebook-1
# once flakes are enabled and the hostname matches a host: nix run .#build-switch
```

> `nix flake check` evaluates the NixOS hosts too, so every registered host
> needs its real hardware-configuration.nix for it to pass. Leaving a
> placeholder host around breaks it at the `fileSystems` assertion.

### Right after the first switch

**The account is created for you; the password is not.** `users.users` in
`common.nix` declares it, so activation creates `jh` — home directory
`/home/jh`, zsh as the shell, and the `wheel`/`networkmanager`/`docker` groups.
But no password is declared anywhere in this repo (`hashedPassword` and
`initialPassword` are both null), so the account is created **locked**: no
tuigreet login, no TTY login, no `su - jh`. Unlock it once as root:

```sh
passwd jh
```

`users.mutableUsers` defaults to `true`, so the password you set survives later
rebuilds. You could declare a hash instead (`initialHashedPassword`) and skip
this step, but this is a public repo — not recommended.

> Not seeing your dev tools in a root shell is expected.
> `modules/nixos/packages.nix` feeds home-manager's `home.packages`, so those
> land in `jh`'s profile only. What's system-wide
> (`environment.systemPackages`) is just `gitFull`/`inetutils` from
> `common.nix` plus the per-host inspection tools.

## Daily usage

The app scripts (`apps/`) are shared across platforms and detect macOS vs NixOS
at runtime, so the same command works on either:

```sh
nix run .#build-switch          # build the new generation and activate it
```

- **macOS** → builds + activates `darwinConfigurations.<arch>` (e.g. `aarch64-darwin`).
- **NixOS** → activates `nixosConfigurations.<hostname>`. The host is taken from
  `hostname`; override it before the first switch with
  `nix run .#build-switch -- --host mn56`.
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
