{ config, lib, pkgs, subline, ... }:

# subline(~/git/subline 의 터치 우선 컴포지터)을 기본 세션과 greetd 로그인 화면으로 쓴다. 세션 배선은
# 그 레포의 nix/module.nix 가 하고, 여기는 기본 세션과 대피 greeter 만 정한다. 다른 세션은 그대로 남는다.
# 로그인 화면이 안 뜨면 Ctrl+Alt+F2 → local.subline.greeter = false 또는 `nix run .#rollback`. 전체: docs/subline.md

let
  cfg = config.local.subline;
in
{
  imports = [ subline.nixosModules.default ];

  options.local.subline = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install the subline session and make it the default one. On by default
        because hosts/nixos/common.nix imports this for every host; set to
        false on a machine that should keep niri as the default and offer no
        subline entry.
      '';
    };
    greeter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Draw greetd's login screen with subline (`subline --greeter`) instead
        of tuigreet. The session list is the same either way; this only changes
        the greeter in front of it. Turn off to get tuigreet back without
        touching the sessions.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.subline = {
      enable = true;
      greeter = cfg.greeter;
    };

    # common.nix 의 mkDefault niri 를 이긴다. "subline" 은 passthru.providedSessions 로 sessionNames 에 있다.
    services.displayManager.defaultSession = "subline";
  };
}
