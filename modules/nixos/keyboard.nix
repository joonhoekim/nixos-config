# keyd 로 evdev 에서 리맵한다(xkb 옵션은 니리·mutter 가 안 읽는다). Right Alt → 한/영, Caps 홀드 → 레이어.
# 전체 그림(TouchCursor 배치, 왼손 마우스, F키 센티넬을 고른 근거): modules/nixos/README.md 「키보드 리맵」
{ ... }:

let
  # modifier 레이어가 아니라 평범한 레이어라, 바인딩 없는 키는 홀드 중에도 그 글자가 나간다.
  nav = {
    i = "up";
    j = "left";
    k = "down";
    l = "right";

    u = "home"; # line start (⌘← in the macOS original)
    o = "end"; # line end   (⌘→)

    h = "pageup";
    n = "pagedown";

    p = "backspace";
    m = "delete"; # forward delete
    y = "insert";

    slash = "C-f"; # find — borrowed from vim, on a key TouchCursor leaves free

    # ./pointer 가 읽는 센티넬. 기본 us 키맵에서 평범한 심볼은 F19·F24 뿐이라 F20/F21/F23 은 피한다
    # (F20 은 XF86AudioMicMute). 옮기기 전에: xkbcli compile-keymap --layout us | grep FK
    w = "f13"; # up
    a = "f14"; # left
    s = "f15"; # down
    d = "f16"; # right

    q = "f17"; # wheel up   / Shift: scroll left
    e = "f18"; # wheel down / Shift: scroll right

    # 같은 센티넬로 나가서 ./pointer 는 둘인 줄 모른다.
    f = "f19"; # left button
    "8" = "f19";
    r = "f24"; # right button
    "0" = "f24";
    "9" = "f22"; # middle button
  };
in
{
  services.keyd = {
    enable = true;

    keyboards.default = {
      ids = [ "*" ];

      settings.main = {
        rightalt = "hangeul"; # keyd's name for KEY_HANGEUL (122)
        capslock = "overload(nav, capslock)";
      };

      settings.nav = nav;
    };
  };
}
