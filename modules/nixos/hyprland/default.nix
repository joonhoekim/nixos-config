{ config, lib, pkgs, user, ... }:

# Hyprland as a third session alongside niri and GNOME, sharing the same
# DankMaterialShell that the niri session runs.
#
# Why a second tiling compositor at all: niri has no output-wide shader hook —
# custom shaders exist only inside window-open/close/resize animations, and
# long-running ones are still an open request upstream (niri #913). Hyprland has
# `decoration:screen_shader`, a fragment shader applied at the end of rendering
# — an output-wide CRT is a one-line setting there and impossible here.
#
# Everything comes from the pinned nixpkgs — no hyprland flake input. That is
# worth stating because most guides still reach for it: nixpkgs carries 0.56,
# which is well past the 0.55 Lua switch, and the upstream flake only starts
# paying for itself once hyprpm plugins need a version-matched compositor.
#
# ── Sessions ───────────────────────────────────────────────────────────────
# programs.hyprland.enable puts *two* entries in the greeter, because the
# package's passthru.providedSessions carries both: "Hyprland" (plain) and
# "Hyprland (uwsm-managed)". Use the uwsm one — it is what wires the shell up
# (see the systemd block below). The plain entry stays as a fallback for when
# uwsm itself is what broke; DMS does not autostart there.
#
# niri remains services.displayManager.defaultSession; tuigreet's
# --remember-session is what actually decides where a login lands.
#
# ── The shader ─────────────────────────────────────────────────────────────
# ./rice/shaders 에 네 갈래 일곱 장이 있고(crt / water / cyberpunk / print),
# ./rice/chains 에 그중 몇을 겹쳐 둔 체인이 있다.
#
# 고르고 겹치고 값을 맞추는 것은 **라이싱 스튜디오**가 한다 — ./rice/studio 의
# QML 이고 apps/rice-studio 가 띄운다. DMS 안이 아니라 별도 창인 이유는 그
# 스크립트 머리말에 있다(요약: 이 축만 성질이 달라서 런처의 항목 계약을 깨고
# 있었다).
#
# DMS 에 남은 것은 여는 단추(DankBar 조각)와 탈출구다. Mod+Shift+C 가 목록을
# 순환하고, 런처(Mod+space 의 `:`)에 off 와 "다음 것"이 있다 — 셰이더가 화면을
# 못 알아보게 만들면 스튜디오 창도 같은 유리 뒤에 있어서, 끄는 길이 거기에만
# 있으면 안 된다.
#
# 셰이더는 ~/git/global-shader-for-macos 에서 왔다. 그쪽은 맥에 없는
# decoration:screen_shader 를 캡처 + 오버레이로 흉내 내는 프로그램이고, 규약을
# 하이프랜드에 맞춰 뒀기 때문에 파일이 양쪽에서 그대로 돈다. 여기 있는 것이
# 사본이라는 뜻이라, 한쪽에서 값을 고쳤으면 다른 쪽도 봐야 한다.
#
# ── 겹치기는 파일 하나로 접어서 넣는다 ────────────────────────────────────
# decoration:screen_shader 는 한 장만 받는다. 여러 칸은 apps/rice-chain 이
# 전처리기로 한 파일에 접어 캐시에 두고, 스위처가 그 경로를 건다. 셰이더 소스는
# 한 글자도 안 고쳐진다 — 왜 그 방법뿐인지, 왜 비용이 합이 아니라 곱인지는 그
# 파일 머리말에 있다.
#
# ── 두 축은 셰이더가 정한다 ───────────────────────────────────────────────
# 셰이더가 걸리면 debug:damage_tracking 은 무조건 0 이다(자기 픽셀 밖을 읽는
# 셰이더는 부분 재합성과 같이 못 산다). debug:vfr 은 흐르는 셰이더에서만 끈다.
# 배터리 값은 vfr 쪽에 붙어 있고, 판정은 `!motion` 표시가 붙은 손잡이가 0 인지로
# 갈린다 — 자세한 건 apps/rice-crt 머리말.
#
# ── Installation is declarative, ricing is not ─────────────────────────────
# Same split as ../niri: this module installs and wires the session, and the
# *settings* live as ordinary writable files under $HOME, seeded from ./rice
# only when missing. Hyprland hot-reloads hyprland.lua on save, and DMS writes
# its own fragments into ~/.config/hypr/dms/ — neither survives a store symlink.

let
  cfg = config.local.hyprland;
in
{
  options.local.hyprland = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install the Hyprland session. On by default because
        hosts/nixos/common.nix imports this for every host; set to false on a
        machine that should offer niri and GNOME only.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;

      # uwsm (Universal Wayland Session Manager) wraps the compositor in systemd
      # units: it starts graphical-session.target, runs XDG autostart, binds the
      # session to the login session and shuts it down in order. Hyprland's own
      # systemd story is thinner than niri's — 0.56 does not even ship a
      # hyprland-session.target any more (the wiki has you hand-write one), and
      # upstream points at uwsm instead.
      #
      # This only flips programs.uwsm.enable. The session entry it is used from
      # comes from the hyprland package itself, not from
      # programs.uwsm.waylandCompositors — that option is for compositors whose
      # package ships no uwsm desktop entry.
      withUWSM = true;
    };

    environment.systemPackages = with pkgs; [
      # niri screenshots itself; hyprland does not. hyprshot wraps grim/slurp
      # and knows how to ask hyprctl for the active window's geometry, which is
      # the one mode a bare `grim -g "$(slurp)"` cannot do.
      hyprshot

      # 셰이더 검증기. apps/rice-chain 이 있으면 쓰고 없으면 넘어가지만, 이
      # 세션에서는 있어야 한다 — 체인은 **생성된 GLSL** 을 거는 것이고,
      # 하이프랜드는 컴파일 실패를 알려 주지 않기 때문이다. 셰이더를 걸어 두고
      # 다음 프레임에 컴파일하며, 실패해도 hyprctl 은 ok 를 돌려주고 로그에도
      # 안 남는다(0.56.1 실측). 그 상태에서 남는 단서는 검은 화면 하나뿐이다.
      glslang
    ];

    # Start DMS in this session too.
    #
    # nixpkgs' dms module writes `wantedBy = [ cfg.systemd.target ]` — a list —
    # so adding to it here leaves ../niri's `systemd.target = "niri.service"`
    # alone rather than fighting over a single string option. The unit is still
    # not wanted by graphical-session.target, so it stays out of GNOME.
    #
    # The instance name is the compositor's desktop entry ID: the entry runs
    # `uwsm start -e -D Hyprland hyprland.desktop`, and uwsm names its units
    # after that argument. Confirm on the machine with:
    #   systemctl --user list-units 'wayland-wm@*'
    #
    # ── 왜 wayland-session@….target 이 아니라 wayland-wm@….service 인가 ──────
    # 저 target 에 걸면 DMS 는 영영 안 뜬다. 세션 로그에 그대로 나온다:
    #
    #   wayland-session@hyprland.desktop.target: Found ordering cycle:
    #     dms.service/start after graphical-session.target/verify-active
    #     after wayland-session@hyprland.desktop.target/start - after dms.service
    #   Job dms.service/start deleted to break ordering cycle
    #
    # 고리의 세 변은 이렇다:
    #
    #   1. target 은 자기가 Wants 하는 유닛에 암묵적으로 After 를 붙인다. 서비스와
    #      달리 target 만의 기본 동작이다(systemd.target(5) — DefaultDependencies
    #      가 no 가 아니면 Wants/Requires 를 After 로 보강한다). 그래서
    #      wantedBy 를 걸어 준 순간 target 이 dms.service 뒤로 밀린다.
    #   2. dms.service 는 자기 유닛에 After=graphical-session.target 을 들고 있다.
    #   3. uwsm 의 wayland-session@.target 은 Before=graphical-session.target 이다.
    #
    # systemd 는 고리를 끊으려고 셋 중 하나를 지우는데, 하필 dms.service 의 시작
    # 작업을 지운다. 그래서 "에러도 없고 유닛은 enabled 인데 화면에 셸이 없는"
    # 상태가 된다.
    #
    # wayland-wm@….service 는 서비스라 1 번 규칙이 없다 — 고리가 안 생긴다.
    # 순서도 맞는다: 저 서비스가 dms 를 끌어오고, dms 는 자기 After 대로
    # graphical-session.target 이 올라온 뒤에 뜬다. ../niri 가 niri.service 에
    # 거는 것과 같은 모양이고, 이쪽이 우연이 아니라 이유가 있었던 셈이다.
    #
    # 종료는 이 줄과 무관하다. dms.service 의 PartOf=graphical-session.target 이
    # 이미 로그아웃 때 같이 내린다.
    systemd.user.services = lib.mkIf config.programs.dms-shell.enable {
      dms.wantedBy = [ "wayland-wm@hyprland.desktop.service" ];
    };

    # Seed the ricing files on a machine that has none yet. Same rules as
    # ../niri: `[ -e ]` guards every copy, so an existing config is never
    # touched and a rebuild mid-ricing cannot clobber unsaved work.
    home-manager.users.${user} = { lib, ... }: {
      home.activation.seedHyprlandRice = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        ${import ../../shared/rice-seed-helpers.nix}

        seed ${./rice/hyprland.lua} "$HOME/.config/hypr/hyprland.lua"

        # 장식 조각의 배선 한 줄. decor.lua 자체는 심지 않는다 — 생성물이고,
        # apps/rice-decor 가 값을 처음 바꿀 때 만든다. 대신 그것을 부르는 줄은
        # 이미 hyprland.lua 를 가진 머신에도 들어가야 한다. seed 는 존재 검사에서
        # 멈추므로 영영 안 들어가고, 그때 증상은 "스튜디오에서 값을 바꾸면 지금은
        # 먹는데 다시 로그인하면 원래대로"다 — 스위처가 성실히 동작하고 화면만
        # 안 따라오는, ../../shared/rice-seed-helpers.nix 머리말이 적어 둔 바로
        # 그 제일 나쁜 상태다.
        # 처음에는 require 였다. require 된 파일은 하이프랜드가 감시해서 스튜디오
        # 슬라이더마다(rice-decor 가 decor.lua 를 다시 쓴다) 설정 전체가 리로드
        # 됐고, 리로드는 걸어 둔 화면 셰이더까지 지운다(rice/hyprland.lua 의 장식
        # 조각 주석). 그래서 dofile 로 바꿨다. ensure 는 붙이기만 하고 못 지우므로
        # 옛 배선이 남은 머신에서는 그 줄부터 걷어낸다 — 안 걷으면 dofile 줄을
        # 붙여도 require 가 다시 감시를 붙인다.
        if [ -f "$HOME/.config/hypr/hyprland.lua" ]; then
          $DRY_RUN_CMD ${pkgs.gnused}/bin/sed -i '/^pcall(require, "decor")$/d' \
            "$HOME/.config/hypr/hyprland.lua"
        fi
        ensure "$HOME/.config/hypr/hyprland.lua" \
          'pcall(dofile, os.getenv("HOME") .. "/.config/hypr/decor.lua")' \
          '-- 장식 값(투명도·흐리게·어둡게·그림자). apps/rice-decor 가 쓴다.'

        # DMS 가 자기 설정을 쓰는 자리. 빈 조각을 미리 깔아 두는 건 DMS 가 처음
        # 뜨기 전에도 hyprland.lua 의 require 가 뭔가를 찾게 하려는 것이다.
        # (require 자체는 pcall 로 감싸 뒀으니 없어도 세션은 뜬다.)
        seed ${./rice/dms} "$HOME/.config/hypr/dms"

        # 화면 셰이더. 갈래 폴더 한 단(crt / water / cyberpunk / print)이고, 그
        # 폴더 이름이 곧 스위처와 런처에서 부르는 이름의 앞부분이다 — `crt/crt`.
        # decoration:screen_shader 는 경로만 받고 ~ 를 풀지 않으므로 전부 절대
        # 경로로 다뤄진다(apps/rice-crt).
        #
        # ── 왜 폴더 하나씩 심는가 ────────────────────────────────────────
        # `seed ${./rice/shaders} "$HOME/.config/hypr/shaders"` 로 통째로 심으면
        # **이미 shaders/ 를 가진 머신에는 새 갈래가 영영 안 들어간다.** seed 의
        # 존재 검사가 부모 폴더에 걸리기 때문이다(../../shared/rice-seed-helpers.nix
        # 머리말의 그 대가다). 셰이더가 평면이던 시절에 리빌드를 한 번이라도 한
        # 머신이 정확히 그 상태이고, 증상은 "런처에 셰이더가 crt 하나뿐"이다.
        #
        # 갈래 단위로 심으면 부모가 있어도 자식이 새로 들어가고, 손댄 셰이더는
        # 여전히 안 덮인다. 목록은 폴더에서 읽으므로 갈래를 추가해도 여기는
        # 안 고친다.
        ${lib.concatMapStringsSep "\n        " (n: ''
          seed ${./rice/shaders}/${n} "$HOME/.config/hypr/shaders/${n}"'')
          (builtins.attrNames (builtins.readDir ./rice/shaders))}

        # 퇴역한 셰이더들. seed 는 지우지 않으므로 $HOME 에는 그대로 남고, 남으면
        # 스위처 목록에 계속 뜬다(`<갈래>/<이름>` 으로 훑으므로 평면 두 장만은
        # 예외로 안 뜬다). 여기서 지우지 않는 것은 값을 손봐 뒀을 수 있어서다 —
        # $HOME 쪽 라이싱 파일을 지우는 것은 rebuild 가 할 일이 아니다. 대신
        # 있다는 사실만 알린다.
        #
        #   crt.frag / crt-motion.frag   평면 시절의 두 장. crt/crt.frag 이 대신한다
        #                                (그 파일 머리말 — 둘은 FOCUS 가 어긋나 있었다)
        #   rain / riso / dither         실기에서 보고 지웠다. 본문이 안 읽히는데
        #                                룩도 값어치가 없었다
        for old in crt.frag crt-motion.frag \
                   cyberpunk/rain.frag print/riso.frag print/dither.frag; do
          if [ -f "$HOME/.config/hypr/shaders/$old" ]; then
            echo "note: ~/.config/hypr/shaders/$old 은 퇴역했다. 값을 손봤다면 옮겨 담고 지울 것"
          fi
        done

        # 이름 붙인 체인. 한 줄에 한 칸이고, 위에서 아래 순서로 겹친다.
        # `apps/rice-crt --save <이름>` 이 여기에 새로 쓰고, 레포로 되받는 것은
        # apps/rice-save 다 — 다른 라이싱 파일과 같은 방향이다.
        seed ${./rice/chains} "$HOME/.config/hypr/chains"

        # 라이싱 스튜디오. quickshell 설정 하나이고 apps/rice-studio 가
        # `quickshell -p` 로 띄운다. 하이프랜드 밑에 두는 것은 화면 셰이더가
        # 이 세션에만 있는 훅이기 때문이고, 창 자체는 니리에서 열어도 뜬다 —
        # 거기서는 값만 고칠 수 있고 거는 것은 안 된다(apps/rice-crt 의 need_session).
        #
        # 셰이더와 달리 폴더 통째로 심는다. 갈래처럼 나중에 늘어나는 것이 아니라
        # 한 벌이고, 안의 파일이 서로를 참조해서 반쪽만 새로 들어가면 오히려
        # 깨진다. 이미 있는 머신에 새 파일이 안 들어가는 대가는 그대로다 —
        # QML 을 고쳤으면 apps/rice-save 로 되받는 것이 이 레포의 방향이다.
        seed ${./rice/studio} "$HOME/.config/rice-studio"

        # 터미널·런처·GTK 는 여기서 심지 않는다. ../niri 와 ../../shared/ghostty
        # 가 이미 같은 파일을 $HOME 에 깔아 두고, 그것들은 컴포지터를 안 가린다.
      '';
    };
  };
}
