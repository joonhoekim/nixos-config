{ config, pkgs, lib, user, ... }:

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
    shell = pkgs.zsh;
  };

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
    # Thread `user` into home-manager modules (separate arg scope from the
    # system modules' specialArgs).
    extraSpecialArgs = { inherit user; };
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
      programs = import ../shared/home-manager.nix { inherit config pkgs lib user; };

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
