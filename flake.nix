{
  description = "jh's macOS + NixOS configuration — three window managers, one keymap, ricing as ordinary files";

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
    # rift (tiling WM). Not in nixpkgs — upstream ships a universal binary via
    # this tap's *formula*, not a cask, so it lands in homebrew.brews rather
    # than homebrew.casks (modules/darwin/brews.nix).
    acsandmann-tap = {
      url = "github:acsandmann/homebrew-tap";
      flake = false;
    };
  };

  # 나머지 input(홈브루 탭들)은 이름으로 안 꺼낸다 — darwinConfigurations 안에서
  # inputs.<이름> 으로 닿고, input 을 하나 늘릴 때 고칠 자리가 위 목록 하나로
  # 줄어든다.
  outputs = inputs@{ self, nixpkgs, home-manager, darwin, ... }:
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
        default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [ bashInteractive git ];
          shellHook = ''
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
      # NixOS at runtime, so every system exposes the same set — macOS 전용인
      # 것(mac-signing-cert, rice-colors)도 목록에 있고, 잘못 부르면 스크립트가
      # 스스로 거절한다.
      #
      # apps/ 의 실행 파일과 이 목록은 짝이다. rice-lib.sh 처럼 sourced 되는
      # 조각만 여기서 뺀다 — 한동안 손으로 하나씩 적다가 새 스크립트(rice-decor)
      # 를 빠뜨린 적이 있어서 목록 하나로 접었다.
      mkApps = system: nixpkgs.lib.genAttrs [
        "build" "build-switch" "rollback" "clean"
        "rice-save" "rice-restore" "rice-switch" "rice-wall" "rice-fuzzel"
        "rice-term" "rice-crt" "rice-chain" "rice-studio" "rice-menu"
        "rice-knobs" "rice-decor" "rice-colors"
        "demo" "mac-signing-cert"
      ] (name: mkApp name system);
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
            inputs.nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                inherit user;
                enable = true;
                taps = {
                  "homebrew/homebrew-core" = inputs.homebrew-core;
                  "homebrew/homebrew-cask" = inputs.homebrew-cask;
                  "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
                  # aerospace lives here; managed declaratively so a fresh
                  # machine never needs an imperative `brew tap` (which fails
                  # on a not-yet-writable /opt/homebrew/Library/Taps).
                  "nikitabobko/homebrew-tap" = inputs.nikitabobko-tap;
                  # rift, same reasoning. Brew refers to this tap as
                  # `acsandmann/tap` (the `homebrew-` prefix is implicit), which
                  # is the spelling modules/darwin/brews.nix uses.
                  "acsandmann/homebrew-tap" = inputs.acsandmann-tap;
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
      #   nixos-rebuild switch --flake .#evo-t1
      #   nixos-rebuild switch --flake .#galaxy-chromebook-1
      nixosConfigurations = let
        # home-manager 배선은 여기 없다 — darwin 이 modules/darwin/home-manager.nix
        # 에 두는 것과 같은 모양으로 hosts/nixos/common.nix 에 있다. flake 는
        # 순수 배선만 한다.
        mkNixosHost = hostModule: nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = inputs // { inherit user; };
          modules = [ hostModule ];
        };
      in {
        mn56 = mkNixosHost ./hosts/nixos/mn56;
        evo-t1 = mkNixosHost ./hosts/nixos/evo-t1;
        galaxy-chromebook-1 = mkNixosHost ./hosts/nixos/galaxy-chromebook-1;
      };
  };
}
