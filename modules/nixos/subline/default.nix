{ config, lib, pkgs, subline, ... }:

# subline(~/git/subline 의 터치 우선 컴포지터)이 이 저장소의 유일한 세션이고 greetd 로그인 화면이다.
# 세션 배선은 그 레포의 nix/module.nix 가 하고, 여기는 기본 세션과 대피 greeter 만 정한다.
# 로그인 화면이 안 뜨면 Ctrl+Alt+F2 → local.subline.greeter = false 또는 `nix run .#rollback`. 전체: docs/subline.md

let
  cfg = config.local.subline;
in
{
  imports = [ subline.nixosModules.default ];

  options.local.subline = {
    greeter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Draw greetd's login screen with subline (`subline --greeter`) instead
        of tuigreet (hosts/nixos/common.nix). Turn off to get tuigreet back
        when the login screen itself fails to come up.
      '';
    };
  };

  config = {
    programs.subline = {
      enable = true;
      greeter = cfg.greeter;
    };

    # sessionData.sessionNames 중 하나여야 한다(services/display-managers/default.nix 의 assertion).
    # "subline" 은 패키지의 passthru.providedSessions 로 거기 들어간다.
    services.displayManager.defaultSession = "subline";
  };
}
