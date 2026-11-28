{ config, lib, pkgs, user, identity, home-manager, ... }:

{
  imports = [
    home-manager.darwinModules.home-manager
    ../../modules/darwin/homebrew.nix
    ../../modules/darwin/casks.nix
    ../../modules/darwin/dock
    ../../modules/darwin/default-apps.nix
    ../../modules/darwin/defaults.nix
    ../../modules/darwin/login-items.nix
    ../../modules/darwin/ios.nix
    # Caps Lock 레이어와 한/영(오른쪽 ⌘ → F18). 레이어는 Windows 와 같은 파일이다.
    ../../modules/darwin/kanata.nix
    # launchd 서비스가 Background App Activity 에 "sh" 가 아니라 제 이름으로 보이게.
    ../../modules/darwin/launchd-names.nix
    ../../modules/darwin/rice
    ../../modules/shared
  ];

  home-manager = {
    useGlobalPkgs = true;
    # NixOS 쪽(hosts/nixos/common.nix)과 같은 값. 경로(/etc/profiles/per-user/<user>/bin)가 갈리면 절대 경로를
    # 요구하는 도구 설정(VS Code 의 todo-tree.ripgrep.ripgrep)을 한 벌로 공유할 수 없다.
    useUserPackages = true;
    # 첫 activation 에서 이미 있는 dotfile(~/.zshrc 등)을 <이름>.backup 으로 옮긴다. 없으면 activation 이 거절한다.
    # apps/uninstall 이 이 확장자로 되돌린다.
    backupFileExtension = "backup";
    # Separate arg scope from system specialArgs.
    extraSpecialArgs = { inherit user identity; bundles = config.local.packages.bundles; };
    users.${user} = import ../../modules/darwin/home-manager.nix;
  };

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

  # 양 플랫폼 공통 값은 modules/shared/nix-settings.nix, nix.package 는 modules/shared/nix-implementation.nix.
  nix = {
    settings.trusted-users = [ "@admin" "${user}" ];
    gc.interval = { Weekday = 0; Hour = 2; Minute = 0; };
  };

  # Touch ID (and Apple Watch) for sudo. `reattach` makes it work inside tmux.
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  # Passwordless sudo. sudoers.d is included at the end of /etc/sudoers, so it wins over `%admin ALL=(ALL) ALL`.
  # It bypasses the Touch ID prompt above: anything running as ${user}, background agents included, reaches root unprompted.
  security.sudo.extraConfig = ''
    ${user} ALL=(ALL) NOPASSWD: ALL
  '';

  # environment.systemPackages 는 두지 않는다 — shared 패키지는 home.packages 로 들어가 여기 넣으면 이중으로 깔린다.

  # Fonts in systemPackages are NOT picked up by macOS apps, so terminals show broken glyphs without this.
  fonts.packages = import ../../modules/shared/fonts.nix { inherit pkgs; } ++ [
    # OnlyOffice 한글 폴백이 Heiti 로 가는 것을 막는 macOS 전용 별칭(overlays/onlyoffice-batang-alias.nix).
    pkgs.onlyoffice-batang-alias
  ];

  system = {
    checks.verifyNixPath = false;
    primaryUser = user;
    # 호스트가 자기 값을 고정한다(hosts/darwin/<이름>/default.nix). 여기 값은 공용 .#<arch> 에만 쓰인다.
    stateVersion = lib.mkDefault 5;

    activationScripts.postActivation.text = ''
      # 경로를 글자 그대로 쓴다 — apps/check/mac 이 `dscl . -create ... UserShell <경로>` 줄을 기대값으로 읽는다.
      if [ "$(dscl . -read /Users/${user} UserShell | awk '{ print $2 }')" != /run/current-system/sw/bin/bash ]; then
        echo "setting login shell of ${user} to bash..." >&2
        dscl . -create /Users/${user} UserShell /run/current-system/sw/bin/bash
      fi
    '';
  };
}
