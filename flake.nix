{
  description = "macOS + NixOS configuration — three window managers, one keymap, ricing as ordinary files";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # With useGlobalPkgs the modules already build against the system pkgs; without `follows`
    # flake.lock pins a second nixpkgs that can silently drift.
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
    # 비공개 레포라 git+https 로 받는다: SSH 키가 GitHub 에 없어 그 호스트에 `gh auth login` 이 필요하다.
    # follows 는 러스트·GTK 스택을 두 벌 짓지 않으려는 것(subline 은 러스트 1.95 이상, 이 nixpkgs 는 1.98).
    subline = {
      url = "git+https://github.com/joonhoekim/subline";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # 받는 사정은 subline 과 같다. macOS 는 nix 가 아니라 apps/subline-terminal 이 빌드·서명한다(docs/subline-terminal.md).
    subline-terminal = {
      url = "git+https://github.com/joonhoekim/subline-terminal";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # 홈브루 탭 input 은 inputs.<이름> 으로 닿으므로 input 을 늘릴 때 고칠 자리는 위 목록 하나다.
  outputs = inputs@{ self, nixpkgs, home-manager, darwin, ... }:
    let
      # specialArgs 는 모듈 평가 전에 정해져야 해서 신원은 호스트 옵션이 아니라 별도 파일이다(users/README.md).
      # throw 가 없으면 한참 뒤 `users.users.""` 근처에서 엉뚱하게 터진다. `git add` 안 한 파일도 여기로 온다.
      identityOf = dir:
        let f = dir + "/identity.nix"; in
        if builtins.pathExists f then import f
        else throw ''
          ${toString dir}/identity.nix 가 없다.
          users/<이름>.nix 를 가리키는 한 줄이면 된다 (users/README.md 참고):
            import ../../../users/<이름>.nix
          이미 만들었다면 `git add` 했는지 확인할 것 — flake 는 추적되지 않는
          파일을 못 본다. `./apps/setup` 이 둘 다 해 준다.
        '';

      # hosts/<플랫폼>/ 아래 디렉토리가 곧 호스트다. 진짜 hardware-configuration.nix 가 없는
      # 디렉토리를 두면 `nix flake check` 가 fileSystems assertion 으로 깨진다.
      hostDirs = dir:
        builtins.attrNames
          (nixpkgs.lib.filterAttrs (_: t: t == "directory") (builtins.readDir dir));
      linuxSystems = [ "x86_64-linux" "aarch64-linux" ];
      # Nixpkgs 26.11 dropped x86_64-darwin (its legacyPackages throw), so listing it breaks evaluation
      # of every output. An Intel Mac would need its own nixpkgs input pinned to the 26.05 darwin branch.
      darwinSystems = [ "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs (linuxSystems ++ darwinSystems) f;
      devShell = system: let pkgs = nixpkgs.legacyPackages.${system}; in {
        default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [ bashInteractive git ];
          shellHook = ''
            export EDITOR=vim
          '';
        };
      } // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
        # `nix develop .#npu`: openvino's NPU plugin dlopens libze_loader.so.1 with no runpath to level-zero,
        # so without this the NPU silently never appears in available_devices. LD_LIBRARY_PATH is safe only
        # because it is shell-scoped and holds nothing but libze_*. 전체 그림: docs/local-inference.md
        npu = pkgs.mkShell {
          nativeBuildInputs = [
            (pkgs.python3.withPackages (ps: with ps; [ openvino numpy ]))
            pkgs.level-zero
            pkgs.openvino
          ];
          shellHook = ''
            export LD_LIBRARY_PATH=${pkgs.level-zero}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
            export ZE_ENABLE_ALT_DRIVERS=/run/opengl-driver/lib/libze_intel_npu.so.1
          '';
        };
      };
      # 이름은 스토어 경로와 `nix run .#<이름>` 에 쓰여 평평해야 하므로 경로(apps/check/mac)와 따로 받는다.
      mkApp = name: path: system: {
        type = "app";
        program = "${(nixpkgs.legacyPackages.${system}.writeScriptBin name ''
          #!/usr/bin/env bash
          PATH=${nixpkgs.legacyPackages.${system}.git}/bin:$PATH
          exec ${self}/apps/${path} "$@"
        '')}/bin/${name}";
      };
      # name 은 공용 호스트면 null. localHostName 만 박는 것은 apps/build-switch 가
      # `scutil --get LocalHostName` 으로 타겟을 고르기 때문이다.
      mkDarwinHost = dir: name: system:
        let
          identity = identityOf dir;
          user = identity.name;
        in
        darwin.lib.darwinSystem {
          inherit system;
          specialArgs = inputs // { inherit user identity; };
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
                };
                # Allow imperative `brew tap`/`brew install` to coexist with Nix.
                mutableTaps = true;
                autoMigrate = true;
              };
            }
            dir
          ]
          ++ nixpkgs.lib.optional (name != null)
               { networking.localHostName = nixpkgs.lib.mkDefault name; };
        };
      # The scripts self-detect macOS vs NixOS at runtime (and refuse on the wrong one), so every system
      # gets the same set. apps/ 의 실행 파일과 짝이다: 여기 안 더하면 `nix run .#<이름>` 만 조용히 없다.
      # sourced 조각(build-lib.sh · rice/lib.sh)만 뺀다.
      mkApps = system: nixpkgs.lib.genAttrs [
        "build" "build-switch" "rollback" "clean" "reclaim" "setup" "doctor"
        "ddc-probe" "inventory" "footprint"
        "demo" "screencast" "mac-signing-cert" "rift-grid" "subline-terminal" "subline-update"
        "kanata"
      ] (name: mkApp name name system)
      // nixpkgs.lib.listToAttrs (map (n: {
        name = "rice-${n}";
        value = mkApp "rice-${n}" "rice/${n}" system;
      }) [
        "save" "restore" "switch" "wall" "fuzzel"
        "term" "crt" "chain" "studio" "menu"
        "knobs" "decor" "layout" "colors"
      ])
      # 점검 스크립트는 플랫폼마다 파일이 갈려서 실행 시점이 아니라 여기서 고른다.
      // (let
            plat = if nixpkgs.lib.hasSuffix "darwin" system then "mac" else "nixos";
          in
          nixpkgs.lib.optionalAttrs (builtins.pathExists ./apps/check/${plat}) {
            check = mkApp "check" "check/${plat}" system;
          })
      // nixpkgs.lib.optionalAttrs (nixpkgs.lib.hasSuffix "darwin" system) {
        check-snapshot = mkApp "check-snapshot" "check/snapshot" system;
      }
      # 평가만 하므로 플랫폼을 가리지 않는다 — 다른 구현체로 모든 호스트를 평가해 본다.
      // { check-eval = mkApp "check-eval" "check/eval" system; };
    in
    {
      devShells = forAllSystems devShell;
      apps = forAllSystems mkApps;

      # 공용 .#<arch>(hosts/darwin/)와 그 Mac 전용 .#<hostname>(hosts/darwin/<이름>/) 두 층이다.
      # 전체 그림: docs/02-this-repo.md
      darwinConfigurations =
        nixpkgs.lib.genAttrs darwinSystems (system: mkDarwinHost ./hosts/darwin null system)
        // nixpkgs.lib.genAttrs (hostDirs ./hosts/darwin)
             (name: mkDarwinHost (./hosts/darwin + "/${name}") name
                      (nixpkgs.lib.head darwinSystems));

      # networking.hostName 은 디렉토리 이름에서만 온다. 호스트 파일에 따로 적어 어긋나면 빌드는 되지만
      # apps/build-switch 의 맨손 호출(`hostname` 으로 타겟을 고른다)이 영영 안 맞는다.
      nixosConfigurations = let
        # home-manager 배선은 hosts/nixos/common.nix 에 있다 — flake 는 순수 배선만 한다.
        mkNixosHost = name:
          let
            dir = ./hosts/nixos + "/${name}";
            identity = identityOf dir;
          in
          nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = inputs // { inherit identity; user = identity.name; };
            modules = [
              dir
              { networking.hostName = nixpkgs.lib.mkDefault name; }
            ];
          };
      in
      nixpkgs.lib.genAttrs (hostDirs ./hosts/nixos) mkNixosHost;
  };
}
