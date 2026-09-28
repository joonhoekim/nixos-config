{
  description = "macOS + NixOS configuration — three window managers, one keymap, ricing as ordinary files";

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
      # 사람에 딸린 값(유저명 · git 신원 · authorized key)은 users/<이름>.nix
      # 한 장이고(계약은 users/README.md), **어느 사람인지는 호스트가 고른다** —
      # hosts/<플랫폼>/<이름>/identity.nix 가 그걸 가리키는 한 줄짜리 파일이다.
      #
      # 왜 호스트 안의 평범한 옵션이 아니라 별도 파일인가: specialArgs 는 모듈이
      # 평가되기 전에 정해져야 해서, 호스트의 default.nix 안에서는 늦다.
      #
      # 없을 때 throw 하는 이유도 같다. 그냥 두면 `import` 가 아니라 한참 뒤
      # `users.users.""` 근처에서 엉뚱하게 터진다. flake 는 **git 이 추적하는
      # 파일만** 스토어로 복사하므로, 파일을 만들어 두고 `git add` 를 안 한
      # 경우도 여기로 떨어진다.
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

      # hosts/<플랫폼>/ 아래의 **디렉토리**가 곧 호스트다. 손으로 적던 목록을
      # 지운 이유: 새 기계를 붙일 때 고칠 자리가 하나(자기 디렉토리)로 줄어야
      # 포크한 쪽이 공유 파일을 안 건드린다. common.nix / default.nix /
      # identity.nix 는 파일이라 자연히 걸러진다.
      #
      # 주의: 여기 걸리는 호스트는 `nix flake check` 가 전부 평가한다. 진짜
      # hardware-configuration.nix 가 없는 디렉토리를 두면 그 자리에서
      # fileSystems assertion 으로 깨진다 — 빈 껍데기를 만들어 두지 말 것.
      hostDirs = dir:
        builtins.attrNames
          (nixpkgs.lib.filterAttrs (_: t: t == "directory") (builtins.readDir dir));
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
      } // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
        # `nix develop .#npu` — OpenVINO with evo-t1's NPU actually reachable.
        #
        # It needs a shell rather than plain systemPackages because of a
        # packaging gap: openvino's NPU plugin reaches Level Zero by
        # dlopen("libze_loader.so.1") at runtime, but nixpkgs gives that .so no
        # runpath entry for level-zero — so the dlopen fails, the plugin
        # reports "No available devices" from inside itself, and the NPU simply
        # never appears in available_devices. (strace shows it looking for
        # libze_loader.so.1 in openvino's, onetbb's and gcc's lib dirs and
        # nowhere else.) Fixing it properly means an overlay that patchelfs the
        # plugin, which costs a full source rebuild of openvino on every
        # nixpkgs bump — far too much for the two lines below.
        #
        # LD_LIBRARY_PATH is safe *here* precisely because it is scoped to this
        # shell and points at a directory holding nothing but libze_*. The same
        # variable in environment.sessionVariables would be inherited by every
        # process on the machine, which is how NixOS setups get mysterious.
        #
        # ZE_ENABLE_ALT_DRIVERS is set for evo-t1 system-wide already
        # (hosts/nixos/evo-t1), and repeated so the shell stands on its own.
        #
        # Verified end to end: available_devices returns
        #   ['CPU', 'GPU', 'NPU'] -> Core Ultra 9 285H / Arc Graphics (iGPU) /
        #   Intel(R) AI Boost
        # and compile_model + inference runs on CPU and GPU. Compiling *for*
        # the NPU still fails, one layer below anything this shell controls —
        # nixpkgs does not build the driver's compiler. hosts/nixos/evo-t1 has
        # the diagnosis; do not spend an evening re-deriving it here.
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
      # 앱 이름과 apps/ 아래 경로를 따로 받는다. 경로에는 `/` 가 들어갈 수 있지만
      # (apps/check/mac) 이름은 스토어 경로와 `nix run .#<이름>` 에 그대로 쓰이므로
      # 평평해야 한다.
      mkApp = name: path: system: {
        type = "app";
        program = "${(nixpkgs.legacyPackages.${system}.writeScriptBin name ''
          #!/usr/bin/env bash
          PATH=${nixpkgs.legacyPackages.${system}.git}/bin:$PATH
          exec ${self}/apps/${path} "$@"
        '')}/bin/${name}";
      };
      # dir 은 호스트 디렉토리, name 은 hostname(공용 호스트면 null).
      # localHostName 만 디렉토리 이름에서 박는다 — `scutil --get LocalHostName`
      # 이 돌려주는 값이 정확히 이것이고, apps/build-switch 가 타겟을 그 값으로
      # 고르기 때문이다. HostName 과 ComputerName 은 건드리지 않는다.
      mkDarwinHost = dir: name: system:
        let
          identity = identityOf dir;
          user = identity.name;
        in
        darwin.lib.darwinSystem {
          inherit system;
          # 신원은 <호스트>/identity.nix 에서 온다. `user` 는 그 한 줄을 꺼내
          # 놓은 것뿐 — `${user}` 로 쓰는 자리가 열댓 곳이다.
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
            dir
          ]
          ++ nixpkgs.lib.optional (name != null)
               { networking.localHostName = nixpkgs.lib.mkDefault name; };
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
        "build" "build-switch" "rollback" "clean" "setup" "doctor"
        "rice-save" "rice-restore" "rice-switch" "rice-wall" "rice-fuzzel"
        "rice-term" "rice-crt" "rice-chain" "rice-studio" "rice-menu"
        "rice-knobs" "rice-decor" "rice-colors"
        "ddc-probe"
        "demo" "mac-signing-cert"
      ] (name: mkApp name name system)
      # 점검 스크립트는 플랫폼마다 보는 것이 거의 겹치지 않아서 파일이 갈린다.
      # 그래서 위와 달리 실행 시점이 아니라 여기서 고른다 — `nix run .#check` 는
      # 어느 쪽에서든 자기 플랫폼의 것을 띄운다. 파일이 아직 없는 플랫폼에는
      # 노출하지 않는다.
      // (let
            plat = if nixpkgs.lib.hasSuffix "darwin" system then "mac" else "nixos";
          in
          nixpkgs.lib.optionalAttrs (builtins.pathExists ./apps/check/${plat}) {
            check = mkApp "check" "check/${plat}" system;
          })
      // nixpkgs.lib.optionalAttrs (nixpkgs.lib.hasSuffix "darwin" system) {
        check-snapshot = mkApp "check-snapshot" "check/snapshot" system;
      };
    in
    {
      devShells = forAllSystems devShell;
      apps = forAllSystems mkApps;

      # macOS 는 두 층이다.
      #
      #   .#<arch>       hosts/darwin/          공용. 전용 디렉토리가 없는 Mac 이
      #                                         전부 이것을 쓴다 (여러 대 + 같은
      #                                         계정이면 이 한 벌로 끝난다).
      #   .#<hostname>   hosts/darwin/<이름>/   그 Mac 전용. 자기 identity.nix 를
      #                                         들고 있어서 계정 이름을 따로 갈 수
      #                                         있다. 있으면 build-switch 가
      #                                         이쪽을 먼저 고른다.
      #
      # 이름이 겹칠 수는 없다 — arch 이름(aarch64-darwin)을 hostname 으로 쓰는
      # 기계는 없다.
      darwinConfigurations =
        nixpkgs.lib.genAttrs darwinSystems (system: mkDarwinHost ./hosts/darwin null system)
        // nixpkgs.lib.genAttrs (hostDirs ./hosts/darwin)
             (name: mkDarwinHost (./hosts/darwin + "/${name}") name
                      (nixpkgs.lib.head darwinSystems));

      # NixOS 호스트는 arch 가 아니라 **hostname** 으로 키잉된다. 목록은
      # hosts/nixos/ 아래 디렉토리 그 자체다(위 hostDirs). 예:
      #   nixos-rebuild switch --flake .#mn56
      #
      # 디렉토리 이름이 hostname 의 유일한 출처다 — networking.hostName 을
      # mkDefault 로 여기서 박는다. 예전에는 호스트가 자기 파일에 따로 적었고,
      # 그러면 둘이 어긋날 수 있었다: 어긋난 순간 apps/build-switch 의 맨손
      # 호출(타겟을 `hostname` 에서 잡는다)이 영영 안 맞는데, 빌드는 멀쩡히
      # 되므로 증상이 "왜 --host 를 계속 붙여야 하지"로만 보인다.
      #
      # 설치 직후 기본값인 `nixos` 가 조용히 살아남는 길도 이걸로 막힌다 —
      # 디렉토리를 그 이름으로 만들지 않는 한.
      nixosConfigurations = let
        # home-manager 배선은 여기 없다 — darwin 이 modules/darwin/home-manager.nix
        # 에 두는 것과 같은 모양으로 hosts/nixos/common.nix 에 있다. flake 는
        # 순수 배선만 한다.
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
