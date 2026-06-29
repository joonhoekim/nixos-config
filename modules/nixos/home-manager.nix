{ config, pkgs, lib, user, ... }:

let
  shared-programs = import ../shared/home-manager.nix { inherit config pkgs lib user; };
  shared-files = import ../shared/files.nix { inherit config pkgs; };
in
{
  home = {
    enableNixpkgsReleaseCheck = false;
    username = "${user}";
    homeDirectory = "/home/${user}";
    packages = pkgs.callPackage ./packages.nix {};
    file = shared-files;
    stateVersion = "25.11";

    # Materialize the tool versions declared in programs.mise.globalConfig
    # at switch time. `mise install` is idempotent (no-op when nothing is
    # missing); `|| true` keeps an offline switch from failing. curl is put
    # on PATH because mise's rust backend shells out to rustup-init, which
    # needs curl/wget — the activation env doesn't otherwise provide it.
    activation.miseInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      PATH="${pkgs.curl}/bin:$PATH" $DRY_RUN_CMD ${config.programs.mise.package}/bin/mise install || true
    '';
  };

  # Dark theme for GTK apps running under Plasma (KDE itself is themed in
  # System Settings).
  gtk = {
    enable = true;
    iconTheme = {
      name = "Adwaita-dark";
      package = pkgs.adwaita-icon-theme;
    };
    theme = {
      name = "Adwaita-dark";
      package = pkgs.adwaita-icon-theme;
    };
  };

  programs = shared-programs // {};
}
