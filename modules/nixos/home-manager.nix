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
    # mkDefault so a host installed at an older release can pin its own (see
    # hosts/nixos/galaxy-chromebook-1). Keep this in sync with the host's
    # system.stateVersion.
    stateVersion = lib.mkDefault "26.11";

    # Materialize the tool versions declared in programs.mise.globalConfig
    # at switch time. `mise install` is idempotent (no-op when nothing is
    # missing). curl is put on PATH because mise's rust backend shells out to
    # rustup-init, which needs curl/wget — the activation env doesn't
    # otherwise provide it.
    #
    # A failure must not abort the switch (an offline machine would never
    # rebuild again), but it must not pass silently either: this swallowed a
    # real breakage once, leaving bun/java/rust uninstalled for as long as it
    # took to notice `bun` was missing. Warn loudly and carry on.
    activation.miseInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      PATH="${pkgs.curl}/bin:$PATH" $DRY_RUN_CMD ${config.programs.mise.package}/bin/mise install \
        || echo "WARNING: 'mise install' failed — some tools declared in programs.mise are missing. Run 'mise install' by hand for the error." >&2
    '';
  };

  # Dark mode. GNOME reads the dconf keys below; the `gtk` block writes
  # ~/.config/gtk-{3,4}.0/settings.ini, which covers GTK apps launched
  # outside a GNOME session (and Xwayland ones that ignore the portal).
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Adwaita-dark";
  };

  gtk = {
    enable = true;
    iconTheme = {
      # adwaita-icon-theme ships only "Adwaita" (no -dark variant); it adapts
      # to the dark GTK theme on its own.
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra; # provides the Adwaita-dark GTK theme
    };
    # From home.stateVersion 26.05 on, gtk4.theme defaults to null instead of
    # inheriting gtk.theme. Set it explicitly so GTK4 apps stay dark too.
    gtk4.theme = config.gtk.theme;
  };

  programs = shared-programs // {};
}
