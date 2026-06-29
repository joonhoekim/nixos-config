{
  description = "Starter Configuration for MacOS and NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
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
      darwinSystems = [ "aarch64-darwin" "x86_64-darwin" ];
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
      # hardware-configuration.nix. Build with e.g.:
      #   nixos-rebuild switch --flake .#amd
      #   nixos-rebuild switch --flake .#intel
      nixosConfigurations = let
        mkNixosHost = hostModule: nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = inputs // { inherit user; };
          modules = [
            home-manager.nixosModules.home-manager {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
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
        amd = mkNixosHost ./hosts/nixos/amd;
        intel = mkNixosHost ./hosts/nixos/intel;
      };
  };
}
