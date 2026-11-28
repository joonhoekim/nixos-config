{ config, pkgs, user, identity, ... }:

# home.file 항목은 여기 없다. macOS 쪽 설정 파일은 전부 ./rice 가 시드한다.
{
  imports = [
   ./casks.nix
   ./dock
  ];

  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
    isHidden = false;
    # 이 값만으로는 로그인 셸이 안 바뀐다 — nix-darwin 은 users.knownUsers 계정에만 UserShell 을 쓴다
    # (modules/users/default.nix). 실제 변경은 아래 dscl 이 한다.
    shell = pkgs.bashInteractive;
  };

  # 로그인 셸은 nix 의 bash 5: bash 를 가정한 스크립트가 zsh 에선 조용히 다르게 돌고, /bin/bash 는 3.2 다.
  # /etc/shells 에 없으면 chsh 가 거절하고 sshd 등이 로그인을 막는다.
  environment.shells = [ pkgs.bashInteractive ];
  # 경로를 글자 그대로 쓴다 — apps/check/mac 이 `dscl . -create ... UserShell <경로>` 줄을 기대값으로 읽는다.
  system.activationScripts.postActivation.text = ''
    if [ "$(dscl . -read /Users/${user} UserShell | awk '{ print $2 }')" != /run/current-system/sw/bin/bash ]; then
      echo "setting login shell of ${user} to bash..." >&2
      dscl . -create /Users/${user} UserShell /run/current-system/sw/bin/bash
    fi
  '';

  home-manager = {
    useGlobalPkgs = true;
    # NixOS 쪽(hosts/nixos/common.nix)과 같은 값. 경로(/etc/profiles/per-user/<user>/bin)가 갈리면 절대 경로를
    # 요구하는 도구 설정(VS Code 의 todo-tree.ripgrep.ripgrep)을 한 벌로 공유할 수 없다.
    useUserPackages = true;
    # Thread `user` into home-manager modules (separate arg scope from the
    # system modules' specialArgs).
    extraSpecialArgs = { inherit user identity; bundles = config.local.packages.bundles; };
    # Back up pre-existing dotfiles (e.g. ~/.zshrc) to <name>.backup instead
    # of refusing to overwrite them on first activation.
    backupFileExtension = "backup";
    users.${user} = { pkgs, config, lib, bundles, ... }:{
      # NixOS 쪽 home-manager 도 같은 모듈을 쓴다(ghostty 자체는 ./casks.nix 가 cask 로 깐다).
      imports = [ ../shared/ghostty ];

      home = {
        enableNixpkgsReleaseCheck = false;
        packages = pkgs.callPackage ./packages.nix { inherit bundles; };
        # 호스트가 자기 값을 고정한다(hosts/darwin/<이름>/default.nix). 여기 값은 공용 .#<arch> 에만 쓰인다.
        stateVersion = lib.mkDefault "23.11";

        activation.miseInstall = import ../shared/mise-install.nix { inherit pkgs lib config; };
        activation.claudeAttribution = import ../shared/claude-attribution.nix { inherit pkgs lib; };
      };
      programs = import ../shared/home-manager.nix { inherit config pkgs lib user identity bundles; };
    };
  };
}
