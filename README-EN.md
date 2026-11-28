# nixos-config

> 한국어: [README.md](README.md)

Personal Nix configuration for macOS (nix-darwin + home-manager) and NixOS.

**The host list is the set of directories under `hosts/<platform>/`.** There is
no separate registry in the flake: a directory's name is both the flake target
and its `networking.hostName`. Attaching a new machine is what `./apps/setup`
does — see [NixOS — first build](#nixos--first-build-on-a-new-machine).

The NixOS configurations are keyed by **hostname**, e.g. `.#mn56`. A host directory only
exists for a machine that actually exists, since it needs that machine's
generated `hardware-configuration.nix`.

On macOS, too, each Mac is one `hosts/darwin/<hostname>/`, keyed by hostname
(`LocalHostName`). A Mac without its own directory uses the shared config keyed
by **architecture** (`hosts/darwin/`, e.g. `.#aarch64-darwin`) — that is for a
new Mac's first switch or a fork; for a Mac you keep using, run `./apps/setup`
on it to create its own directory. Intel Macs (`x86_64-darwin`) are dropped, since
nixpkgs 26.11 removed support; reviving one means a separate nixpkgs input
pinned to the 26.05 darwin branch.

Account name, git identity and authorized keys live in one file,
`users/<name>.nix` (the contract is in [users/README.md](users/README.md)); each
host picks whose it is in `hosts/<platform>/<name>/identity.nix`. Those two are
the only files a fork edits, so `git pull` never conflicts.

The desktop is a single session on top of greetd: **subline**, a touch-first
compositor ([modules/nixos/subline](modules/nixos/subline)) that also draws the
login screen, the shell and the on-screen keyboard. No desktop-environment
module is enabled, so the plumbing such a module would turn on (keyring,
bluetooth, upower, udisks2, …) is declared directly in
[modules/nixos/desktop.nix](modules/nixos/desktop.nix), and the everyday apps
(camera, image viewer, …) live in
[modules/nixos/gui-apps.nix](modules/nixos/gui-apps.nix).

Ricing files (the terminal look, the macOS window-manager config) are not
managed by Nix. They are ordinary writable files under `~/.config`, so apps
hot-reload them on save. The repo copy is a backup and a seed for a fresh
machine; `apps/rice/save` snapshots the live config back into it. A rebuild
pushes repo changes into files you have not touched, and `apps/rice/restore`
overwrites the ones you have ([docs/rice-seeding.md](docs/rice-seeding.md)).

Switching the terminal look applies instantly — no restart, no rebuild:

```sh
apps/rice/term                # current terminal look + list
apps/rice/term crt            # off | glow | crt
```

## Bootstrap — macOS (first run on a new machine)

The repo is private: cloning it and the first build both need a GitHub login.
See [docs/github-auth.md](docs/github-auth.md) for borrowing gh from nixpkgs
until the first switch installs it.

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
needs `--extra-experimental-features 'nix-command flakes'`).

Everything after that is `./apps/setup`'s job. **Call it by path, not as
`nix run .#setup`** — this repo is what turns flakes on
(`hosts/nixos/common.nix`), so on a freshly installed NixOS `nix run` does not
work yet. That is also why the script assumes nothing beyond sh, coreutils, git
and `nixos-generate-config`.

The repo is private, so log in to GitHub first. gh is not installed yet, so
borrow it from nixpkgs and stay in that shell through the first build (why:
[docs/github-auth.md](docs/github-auth.md)).

```sh
nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#gh
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=credential.https://github.com.helper GIT_CONFIG_VALUE_0='!gh auth git-credential'
gh auth login
gh repo clone joonhoekim/nixos-config ~/nixos-config
cd ~/nixos-config
./apps/setup
```

It asks four things, and all four are **facts Nix evaluation cannot see** — pure
evaluation reads neither `/etc/passwd` nor `hostname`, so when one is wrong the
build still succeeds and the symptom shows up much later:

| Question | Why it is confirmed here |
|---|---|
| account name | If it differs from the current one, activation creates a **second** account and you end up with two homes |
| git user.name / email | Goes into `users/<name>.nix`; an existing file is reused as-is |
| hostname | Stops the installer default `nixos` from quietly sticking. This name becomes the directory name and the flake target |
| `system.stateVersion` | The release this machine was **first installed at** — it pins state compatibility, not the channel |

It writes `users/<name>.nix`, `hosts/nixos/<hostname>/{default.nix,identity.nix}`
and a `hardware-configuration.nix` from `nixos-generate-config`, adding the right
`modules/nixos/{intel,amd}.nix` based on the CPU vendor. Finally it runs
`git add` — **a flake only sees files git tracks.** Skip that and the host you
just created is treated as absent, with the error surfacing somewhere unrelated.

Then build:

```sh
./apps/build-switch --host <hostname>
```

`--host` is needed exactly once. This machine's `hostname` is still the old one,
so the bare call would miss; after the switch `networking.hostName` matches the
directory name and `nix run .#build-switch` is enough from then on. (When it
does miss, `build-switch` stops and prints the hosts that do exist.)

### Doing it by hand

All `setup` does is write three files:

```sh
mkdir -p hosts/nixos/<hostname>
sudo nixos-generate-config --show-hardware-config \
  > hosts/nixos/<hostname>/hardware-configuration.nix
echo 'import ../../../users/<name>.nix' > hosts/nixos/<hostname>/identity.nix
# default.nix imports ../common.nix and ./hardware-configuration.nix and sets
# system.stateVersion — copy an existing host.
git add users hosts/nixos/<hostname>
```

Do **not** write `networking.hostName`. `flake.nix` sets it from the directory
name with `mkDefault`; writing it twice lets the two drift, and since the build
still succeeds the only symptom is "why do I keep needing `--host`".

For SSH key auth, put your public key in `authorizedKeys` in
`users/<name>.nix`. Leave it empty and `openssh` accepts account passwords only.

> `nix flake check` evaluates every registered NixOS host, and the host
> directories *are* the registry — so a directory without a real
> `hardware-configuration.nix` breaks it at the `fileSystems` assertion. Don't
> leave empty shells around.

### Right after the first switch

**The account is created for you; the password is not.** `users.users` in
`common.nix` declares it, so activation creates the account named in
`users/<name>.nix` — home directory, zsh as the shell, and the
`wheel`/`networkmanager`/`docker` groups. But no password is declared anywhere in
this repo (`hashedPassword` and `initialPassword` are both null), so the account
is created **locked**: no tuigreet login, no TTY login, no `su - <name>`. Unlock
it once as root:

```sh
passwd <name>
```

`users.mutableUsers` defaults to `true`, so the password you set survives later
rebuilds. You could declare a hash instead (`initialHashedPassword`) and skip
this step, but passwords stay out of the repo. `./apps/doctor` points
out a locked account.

> Not seeing your dev tools in a root shell is expected.
> `modules/nixos/packages.nix` feeds home-manager's `home.packages`, so those
> land in that account's profile only. What's system-wide
> (`environment.systemPackages`) is just `gitFull`/`inetutils` from
> `common.nix` plus the per-host inspection tools.

## Daily usage

The app scripts (`apps/`) are shared across platforms and detect macOS vs NixOS
at runtime, so the same command works on either:

```sh
nix run .#build-switch          # build the new generation and activate it
```

- **macOS** → builds + activates this Mac's own host
  (`hosts/darwin/<hostname>/`) when it exists, otherwise the shared
  `darwinConfigurations.<arch>` (e.g. `aarch64-darwin`).
- **NixOS** → activates `nixosConfigurations.<hostname>`. The host is taken from
  `hostname`; override it before the first switch with
  `nix run .#build-switch -- --host mn56`.
- If the target name is not a host, it stops before building and prints the
  hosts that do exist.
- **Don't prefix it with `sudo`.** The script builds as your user, then calls
  `sudo` only for the activation step. Running the whole thing as root breaks
  git ownership checks on the repo.
- Extra flags pass through, e.g. `nix run .#build-switch -- --show-trace`.

To call the rebuild tools directly instead, name the config explicitly (a bare
`.#` resolves by hostname, which won't match the arch-named shared config on a
Mac without its own directory):

```sh
sudo darwin-rebuild switch --flake .#<host>   # macOS (aarch64-darwin for the shared config)
sudo nixos-rebuild  switch --flake .#<host>   # NixOS
```

## Other flake apps

```sh
nix run .#build               # build only, no switch (verify it evaluates)
nix run .#rollback            # roll back to a previous generation
nix run .#clean               # garbage-collect old generations (default 7d; e.g. `-- 14d`)

nix run .#setup               # attach a new machine to the repo (interactive). Before
                              #   the first build use ./apps/setup — flakes are still off
nix run .#doctor              # check this machine against this checkout (changes nothing)

nix run .#demo                # macOS only — replay real window-manager usage on an empty workspace
nix run .#rice-colors         # macOS only — pywal palette push
nix run .#mac-signing-cert    # macOS only — pin the code-signing identity (docs/03)
```

The ricing family (rice-term · rice-save · rice-restore) is covered in
the ricing section above and in each script's header. The full list lives in
`flake.nix` (`mkApps`).
