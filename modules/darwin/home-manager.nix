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

  homebrew = {
    enable = true;
    # tap 이름을 Brewfile 에도 적는다 — 없으면 cleanup 을 켠 호스트에서 brew bundle 이 스토어 링크인
    # tap 을 untap 하려다 Permission denied 로 실패한다.
    taps = builtins.attrNames config.nix-homebrew.taps;
    # casks 는 ./casks.nix 가 채운다. formula 는 nixpkgs(modules/shared/packages.nix)로, 꼭 brew 여야 하면 `brews`.
    # onActivation.cleanup = "uninstall";

    # masApps 는 ./ios.nix 에 있다(Xcode).
  };

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
        stateVersion = "23.11";

        activation.miseInstall = import ../shared/mise-install.nix { inherit pkgs lib config; };
        activation.claudeAttribution = import ../shared/claude-attribution.nix { inherit pkgs lib; };
      };
      programs = import ../shared/home-manager.nix { inherit config pkgs lib user identity bundles; };
    };
  };

  local.dock = {
    enable = true;
    username = user;
    # 없는 앱을 남기면 dockutil 이 못 넣어 원하는 목록과 Dock 이 영영 안 맞고, activation 마다 Dock 을
    # 비우고 다시 채운다.
    entries = let
      casks = map (c: c.name) config.homebrew.casks;
    in map (e: removeAttrs e [ "cask" ])
      (builtins.filter (e: !(e ? cask) || builtins.elem e.cask casks) [
      # NOTE: Finder is auto-pinned at the far left (slot 1) by macOS, so it is
      # not listed here — adding it would create a duplicate icon.
      { path = "/Applications/Visual Studio Code.app/"; cask = "visual-studio-code"; }
      { path = "/Applications/Google Chrome.app/"; cask = "google-chrome"; }
      # 손으로 까는 앱이라 없을 수 있다. 경로가 없으면 dockutil 이 경고만 하고 넘어간다.
      { path = "/Applications/Claude.app/"; }
      { path = "/Applications/Zed.app/"; cask = "zed"; }
      { path = "/Applications/Brave Browser.app/"; cask = "brave-browser"; }
      { path = "/Applications/Ghostty.app/"; cask = "ghostty"; }
      { path = "/Applications/DBeaver.app/"; cask = "dbeaver-community"; }
      { path = "/Applications/Redis Insight.app/"; cask = "redis-insight"; }
      { path = "/Applications/Bruno.app/"; cask = "bruno"; }
      { path = "/System/Applications/Messages.app/"; }
      { path = "/System/Applications/Utilities/Activity Monitor.app/"; }
      { path = "/System/Applications/System Settings.app/"; }
    ]);
  };

}
