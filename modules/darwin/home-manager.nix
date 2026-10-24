{ config, pkgs, lib, user, identity, ... }:

# home.file 항목은 여기 없다. macOS 쪽 설정 파일은 전부 ./rice 가 시드한다.
{
  imports = [
   ./dock
  ];

  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
    isHidden = false;
    # 이 값만으로는 로그인 셸이 바뀌지 않는다. nix-darwin 은 users.knownUsers 에
    # 든 계정에만 UserShell 을 쓰고, 관리자 계정은 거기 넣지 말라고 한다
    # (modules/users/default.nix). 여기서는 bash 를 시스템에 까는 역할과 아래
    # 활성화 스크립트가 가리킬 경로를 정하는 역할만 한다.
    shell = pkgs.bashInteractive;
  };

  # 로그인 셸 = nix 의 bash 5. 에이전트가 셸 스크립트를 bash 로 가정하고 쓰는데
  # macOS 기본인 zsh 에서 돌면 단어 분리 같은 차이로 조용히 다르게 동작한다.
  # /bin/bash 는 3.2 라 연관 배열 등이 없어서 쓰지 않는다.
  #
  # /etc/shells 에 없는 셸은 chsh 가 거절하고 일부 도구(sshd 등)가 로그인을
  # 막으므로 먼저 등록한다. 경로는 세대가 바뀌어도 같은 /run/current-system/sw/bin/bash.
  environment.shells = [ pkgs.bashInteractive ];
  #
  # 경로를 변수로 빼지 않고 글자 그대로 쓴다 — apps/check/mac 이 activate 에서
  # `dscl . -create ... UserShell <경로>` 줄을 읽어 기대값으로 삼는다.
  system.activationScripts.postActivation.text = ''
    if [ "$(dscl . -read /Users/${user} UserShell | awk '{ print $2 }')" != /run/current-system/sw/bin/bash ]; then
      echo "setting login shell of ${user} to bash..." >&2
      dscl . -create /Users/${user} UserShell /run/current-system/sw/bin/bash
    fi
  '';

  homebrew = {
    enable = true;
    # Taps are managed declaratively via nix-homebrew in flake.nix, so no
    # `homebrew.taps` entry is needed here.
    casks = pkgs.callPackage ./casks.nix {};
    brews = pkgs.callPackage ./brews.nix {};
    # onActivation.cleanup = "uninstall";

    # masApps 는 ./ios.nix 에 있다(Xcode).
  };

  home-manager = {
    useGlobalPkgs = true;
    # NixOS 쪽(hosts/nixos/common.nix)과 같은 값. 켜지 않으면 home.packages 가
    # ~/.nix-profile/bin 으로 가고, 켜면 /etc/profiles/per-user/<user>/bin 으로
    # 간다. 두 플랫폼의 경로가 갈리면 절대 경로를 요구하는 도구 설정을 한 벌로
    # 공유할 수 없다 — VS Code 의 todo-tree.ripgrep.ripgrep 가 그 사례였다.
    useUserPackages = true;
    # Thread `user` into home-manager modules (separate arg scope from the
    # system modules' specialArgs).
    extraSpecialArgs = { inherit user identity; };
    # Back up pre-existing dotfiles (e.g. ~/.zshrc) to <name>.backup instead
    # of refusing to overwrite them on first activation.
    backupFileExtension = "backup";
    users.${user} = { pkgs, config, lib, ... }:{
      # 터미널 라이싱(셰이더 포함). NixOS 쪽 home-manager 도 같은 모듈을 쓴다 —
      # ghostty 는 여기서 cask 로 깔리고(./casks.nix), custom-shader 는 문서상
      # 모든 플랫폼이라 조각을 한 벌만 둔다. 자세한 건 그 모듈의 머리말.
      imports = [ ../shared/ghostty ];

      home = {
        enableNixpkgsReleaseCheck = false;
        packages = pkgs.callPackage ./packages.nix {};
        stateVersion = "23.11";

        # mise 도구 설치. NixOS 와 같은 조각을 쓴다.
        activation.miseInstall = import ../shared/mise-install.nix { inherit pkgs lib config; };
        activation.claudeAttribution = import ../shared/claude-attribution.nix { inherit pkgs lib; };
      };
      programs = import ../shared/home-manager.nix { inherit config pkgs lib user identity; };
    };
  };

  local.dock = {
    enable = true;
    username = user;
    entries = [
      # NOTE: Finder is auto-pinned at the far left (slot 1) by macOS, so it is
      # not listed here — adding it would create a duplicate icon.
      { path = "/Applications/Visual Studio Code.app/"; }
      { path = "/Applications/Google Chrome.app/"; }
      # 손으로 까는 앱이라 없을 수 있다. 경로가 없으면 dockutil 이 경고만 하고 넘어간다.
      { path = "/Applications/Claude.app/"; }
      { path = "/Applications/Zed.app/"; }
      { path = "/Applications/Brave Browser.app/"; }
      { path = "/Applications/Ghostty.app/"; }
      { path = "/Applications/DBeaver.app/"; }
      { path = "/Applications/Redis Insight.app/"; }
      { path = "/Applications/Bruno.app/"; }
      { path = "/System/Applications/Messages.app/"; }
      { path = "/System/Applications/Utilities/Activity Monitor.app/"; }
      { path = "/System/Applications/System Settings.app/"; }
    ];
  };

}
