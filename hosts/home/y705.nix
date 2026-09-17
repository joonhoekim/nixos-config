{ config, pkgs, lib, user, ... }:

# Standalone home-manager for the Debian chroot on the Y705 tablet
# (Legion Tab Y700 5th Gen, aarch64-linux). There is no NixOS underneath —
# Nix is a single-user install inside the chroot — so this is the only place
# that wires home-manager for that machine.
#
#   home-manager switch --flake ~/nixos-config#jh@y705
#
# The chroot runs on the stock GKI kernel, which has no user namespaces, so
# nix.conf there sets `sandbox = false`. Nothing in this module depends on
# the sandbox, but a build that insists on it will fail.
let
  shared-programs = import ../../modules/shared/home-manager.nix {
    inherit config pkgs lib user;
  };
in
{
  home = {
    enableNixpkgsReleaseCheck = false;
    username = user;
    homeDirectory = "/home/${user}";
    stateVersion = "26.11";

    # A headless terminal machine: no GUI, no fonts, no container tooling
    # (the kernel cannot run containers — see the y705 repo's kernel notes).
    # modules/shared/packages.nix is deliberately not reused; it carries the
    # desktop and macOS-side tools.
    packages = with pkgs; [
      bat
      btop
      curl
      fd
      file
      gnumake
      htop
      jq
      killall
      nix-output-monitor
      openssh
      ripgrep
      rsync
      sqlite
      tree
      unzip
      wget
      zip
    ];
  };

  # zsh, git, cli (direnv/mise/zoxide/eza), vim, ssh, tmux — the same
  # fragments the macOS and NixOS hosts use. The darwin-only parts inside
  # them are already guarded by `pkgs.stdenv.hostPlatform.isDarwin`.
  #
  # The mise *activation* (modules/shared/mise-install.nix) is left out on
  # purpose: it would download node/rust toolchains on every switch, over the
  # tablet's Wi-Fi, into an image that is meant to stay small. Run
  # `mise install` by hand when a project needs it.
  programs = shared-programs // {
    home-manager.enable = true;

    # The shared zsh fragment sources the *multi-user* Nix profile
    # (/nix/var/nix/profiles/default/...), which the other hosts have. Nix
    # here is a single-user install inside the chroot, so that path does not
    # exist and the login shell would come up without ~/.nix-profile/bin on
    # PATH — every tool home-manager installed would look missing.
    zsh = shared-programs.zsh // {
      envExtra = (shared-programs.zsh.envExtra or "") + ''
        [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ] \
          && . "$HOME/.nix-profile/etc/profile.d/nix.sh"
        [ -e "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ] \
          && . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      '';
    };
  };
}
