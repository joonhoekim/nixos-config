{ config, pkgs, lib, user, identity, ... }:

# home.file 항목은 여기 없다. macOS 쪽에 심링크로 걸던 셋(karabiner.json,
# aerospace.toml, rift 의 config.toml)이 2026-08-06 에 전부 시드로 옮겨
# 갔고(./rice), 그러고 나니 파일에 남는 항목이 하나도 없어서 files.nix 자체를
# 지웠다 — 빈 껍데기만 남아 있던 shared 쪽도 같이 지웠다.
{
  imports = [
   ./dock
  ];

  # It me
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
    # nikitabobko/tap (aerospace) and acsandmann/tap (rift) are managed
    # declaratively via nix-homebrew in flake.nix, so no `homebrew.taps` entry
    # is needed here.
    casks = pkgs.callPackage ./casks.nix {};
    brews = pkgs.callPackage ./brews.nix {};
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
    #
    # Xcode is declared in ./ios.nix (masApps merges across modules).
    masApps = {
      # "wireguard" = 1451685025;
    };
  };

  # Enable home-manager
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

        # mise 도구 설치. NixOS 와 같은 것을 쓴다 — 예전에는 여기만 `|| true` 로
        # 실패를 삼키는 옛 판이었고, 그 반쪽 수정이 이 조각으로 접은 이유다.
        activation.miseInstall = import ../shared/mise-install.nix { inherit pkgs lib config; };
      };
      programs = import ../shared/home-manager.nix { inherit config pkgs lib user identity; };

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
      { path = "/Applications/Visual Studio Code.app/"; }
      { path = "/Applications/Google Chrome.app/"; }
      { path = "/Applications/Claude.app/"; } # NOTE: Claude is installed manually (not declaratively managed), so it may be missing. dockutil just warns and skips it if the path doesn't exist.
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
