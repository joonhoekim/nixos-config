{
  description = "Starter Configuration for MacOS and NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # `follows` keeps home-manager on the same nixpkgs as everything else.
    # useGlobalPkgs = true means the modules already build against the system's
    # pkgs, so without this the only effect was a second nixpkgs pinned in
    # flake.lock — extra fetches and a channel that could silently drift.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    nikitabobko-tap = {
      url = "github:nikitabobko/homebrew-tap";
      flake = false;
    };
  };

  outputs = { self, darwin, nix-homebrew, homebrew-bundle, homebrew-core, homebrew-cask, nikitabobko-tap, home-manager, nixpkgs } @inputs:
    let
      user = "jh";
      linuxSystems = [ "x86_64-linux" "aarch64-linux" ];
      # Apple Silicon only. Nixpkgs 26.11 dropped x86_64-darwin outright — its
      # legacyPackages now `throw` on evaluation — so listing it here does not
      # produce a degraded Intel config, it makes `darwinConfigurations` and
      # every forAllSystems output fail to evaluate at all. If an Intel Mac
      # ever needs to be served, it wants its own nixpkgs input pinned to the
      # 26.05 darwin branch (supported until end of 2026), not a line here.
      darwinSystems = [ "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs (linuxSystems ++ darwinSystems) f;
      devShell = system: let pkgs = nixpkgs.legacyPackages.${system}; in {
        default = with pkgs; mkShell {
          nativeBuildInputs = with pkgs; [ bashInteractive git ];
          shellHook = with pkgs; ''
            export EDITOR=vim
          '';
        };
      };
      mkApp = scriptName: system: {
        type = "app";
        program = "${(nixpkgs.legacyPackages.${system}.writeScriptBin scriptName ''
          #!/usr/bin/env bash
          PATH=${nixpkgs.legacyPackages.${system}.git}/bin:$PATH
          exec ${self}/apps/${scriptName} "$@"
        '')}/bin/${scriptName}";
      };
      # The app scripts are shared across platforms and self-detect macOS vs
      # NixOS at runtime, so every system exposes the same set.
      mkApps = system: {
        "build-switch" = mkApp "build-switch" system;
        "build" = mkApp "build" system;
        "rollback" = mkApp "rollback" system;
        "clean" = mkApp "clean" system;
        "rice-save" = mkApp "rice-save" system;
        "rice-restore" = mkApp "rice-restore" system;
        "rice-switch" = mkApp "rice-switch" system;
        "rice-wall" = mkApp "rice-wall" system;
        "rice-fuzzel" = mkApp "rice-fuzzel" system;
        "rice-term" = mkApp "rice-term" system;
        "rice-crt" = mkApp "rice-crt" system;
      };
    in
    {
      devShells = forAllSystems devShell;
      apps = forAllSystems mkApps;

      darwinConfigurations = nixpkgs.lib.genAttrs darwinSystems (system:
        darwin.lib.darwinSystem {
          inherit system;
          # `user` is the single source of truth (defined once above) threaded
          # into every system module via specialArgs.
          specialArgs = inputs // { inherit user; };
          modules = [
            home-manager.darwinModules.home-manager
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                inherit user;
                enable = true;
                taps = {
                  "homebrew/homebrew-core" = homebrew-core;
                  "homebrew/homebrew-cask" = homebrew-cask;
                  "homebrew/homebrew-bundle" = homebrew-bundle;
                  # aerospace lives here; managed declaratively so a fresh
                  # machine never needs an imperative `brew tap` (which fails
                  # on a not-yet-writable /opt/homebrew/Library/Taps).
                  "nikitabobko/homebrew-tap" = nikitabobko-tap;
                };
                # Allow imperative `brew tap`/`brew install` to coexist with Nix.
                mutableTaps = true;
                autoMigrate = true;
              };
            }
            ./hosts/darwin
          ];
        }
      );

      # NixOS hosts are keyed by hostname (not arch) so multiple physical
      # machines can share ./hosts/nixos/common.nix while each pins its own
      # hardware-configuration.nix. Only machines that actually exist are
      # listed: a host entry is worth nothing without that machine's real
      # hardware-configuration.nix, and a placeholder one only breaks
      # `nix flake check`. Build with e.g.:
      #   nixos-rebuild switch --flake .#mn56
      #   nixos-rebuild switch --flake .#galaxy-chromebook-1
      nixosConfigurations = let
        mkNixosHost = hostModule: nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = inputs // { inherit user; };
          modules = [
            home-manager.nixosModules.home-manager {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                # Rename rather than refuse. home-manager aborts the whole
                # activation when a file it wants to link already exists as a
                # real file, and that takes the rebuild down with it — which is
                # exactly what happened on galaxy-chromebook-1 once DMS had
                # written ~/.config/gtk-*/settings.ini itself.
                #
                # This repo deliberately leaves most of $HOME writable so the
                # desktop can tune itself, so that collision is a standing risk
                # rather than a one-off. A backup copy is a better outcome than
                # a machine that cannot rebuild.
                backupFileExtension = "hm-bak";
                # Thread `user` into home-manager modules (separate arg scope
                # from the system modules' specialArgs).
                extraSpecialArgs = { inherit user; };
                users.${user} = import ./modules/nixos/home-manager.nix;
              };
            }
            hostModule
          ];
        };
      in {
        mn56 = mkNixosHost ./hosts/nixos/mn56;
        galaxy-chromebook-1 = mkNixosHost ./hosts/nixos/galaxy-chromebook-1;
      };
  };
}
