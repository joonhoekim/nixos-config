# 보관본 — 아무도 import 하지 않는다. ./keyboard.nix 자리에 넣으면 그대로 돈다.
# Caps 홀드 vim 레이어. 왜 접었는지(OS 에는 모드·문법이 없고 Shift 를 명령에 쓴다): docs/keymap.md
{ ... }:

let
  # 평범한 레이어라 바인딩 없는 키는 그 글자가 나가고, Shift 는 통과해 Caps+Shift+j 가 선택을 늘린다.
  nav = {
    h = "left";
    j = "down";
    k = "up";
    l = "right";

    # Ctrl-arrow 가 리눅스의 단어 이동이다.
    w = "C-right";
    e = "C-right";
    b = "C-left";

    "0" = "home"; # line start ($ = Shift-4 -> end, in [nav+shift])
    g = "C-home"; # gg -> document top (G -> bottom, in [nav+shift])

    slash = "C-f"; # / -> find
    n = "C-g"; # n -> find next. GTK/Firefox/Chromium; some apps want F3.

    u = "C-z"; # undo
    x = "delete"; # x -> delete under cursor (X -> backspace, in [nav+shift])
    y = "C-c"; # yank -> copy
    p = "C-v"; # put -> paste
  };
in
{
  services.keyd = {
    enable = true;

    keyboards.default = {
      ids = [ "*" ];

      settings.main = {
        rightalt = "hangeul";
        capslock = "overload(nav, capslock)";
      };

      settings.nav = nav;

      # [nav+shift] 는 Shift 를 떼고 내보내 `$` 가 Shift-End 가 아니라 End 가 된다. 합성 레이어는 원 레이어 뒤에
      # 선언해야 해서 extraConfig 다. `[` `]` 는 섹션 머리로 읽혀 leftbrace/rightbrace 로 쓴다.
      extraConfig = ''
        [nav+shift]

        # $ -> line end
        4 = end
        # { -> paragraph up
        leftbrace = C-up
        # } -> paragraph down
        rightbrace = C-down
        # G -> document bottom
        g = C-end
        # N -> find previous
        n = C-S-g
        # X -> delete backwards
        x = backspace
      '';
    };
  };
}
