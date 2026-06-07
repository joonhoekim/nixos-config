{ config, pkgs, lib, home-manager, ... }:

let
  user = "jh";
  sharedFiles = import ../shared/files.nix { inherit config pkgs; };
  additionalFiles = import ./files.nix { inherit user config pkgs; };
in
{
  imports = [
   ./dock
  ];

  # It me
  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
    isHidden = false;
    shell = pkgs.zsh;
  };

  homebrew = {
    enable = true;
    # nikitabobko/tap (aerospace) is managed declaratively via nix-homebrew
    # in flake.nix, so no `homebrew.taps` entry is needed here.
    casks = pkgs.callPackage ./casks.nix {};
    # onActivation.cleanup = "uninstall";

    # These app IDs are from using the mas CLI app
    # mas = mac app store
    # https://github.com/mas-cli/mas
    #
    # $ nix shell nixpkgs#mas
    # $ mas search <app name>
    #
    # If you have previously added these apps to your Mac App Store profile (but not installed them on this system),
    # you may receive an error message "Redownload Unavailable with This Apple ID".
    # This message is safe to ignore. (https://github.com/dustinlyons/nixos-config/issues/83)
    masApps = {
      # "wireguard" = 1451685025;
    };
  };

  # Enable home-manager
  home-manager = {
    useGlobalPkgs = true;
    # Back up pre-existing dotfiles (e.g. ~/.zshrc) to <name>.backup instead
    # of refusing to overwrite them on first activation.
    backupFileExtension = "backup";
    users.${user} = { pkgs, config, lib, ... }:{
      home = {
        enableNixpkgsReleaseCheck = false;
        packages = pkgs.callPackage ./packages.nix {};
        file = lib.mkMerge [
          sharedFiles
          additionalFiles
        ];
        stateVersion = "23.11";
      };
      programs = {} // import ../shared/home-manager.nix { inherit config pkgs lib; };

      # Marked broken Oct 20, 2022 check later to remove this
      # https://github.com/nix-community/home-manager/issues/3344
      manual.manpages.enable = false;
    };
  };

  # Fully declarative dock using the latest from Nix Store
  local.dock = {
    enable = true;
    username = user;
    entries = [
      # NOTE: Finder is auto-pinned at the far left (slot 1) by macOS, so it is
      # not listed here — adding it would create a duplicate icon.
      { path = "/Applications/Google Chrome.app/"; }
      { path = "/Applications/Visual Studio Code.app/"; }
      { path = "/Applications/Ghostty.app/"; }
      { path = "/System/Applications/Utilities/Activity Monitor.app/"; }
      { path = "/System/Applications/System Settings.app/"; }
      { path = "/System/Applications/Messages.app/"; }
    ];
  };

}
