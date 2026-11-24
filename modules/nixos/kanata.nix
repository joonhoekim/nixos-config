# Caps Lock 레이어와 Right Alt → 한/영을 kanata 로 건다. 레이어 본체는 ../shared/kanata/nav.kbd 이고
# (Windows·Debian 과 같은 파일), 여기는 NixOS 에만 해당하는 기본 레이어와 defcfg 만 둔다.
# xkb 옵션이 아닌 이유: 포인터 이동(REL_X/REL_Y)까지 한 설정에서 내려면 evdev 에서 잡아야 한다.
#
# nixpkgs 모듈이 빌드 때 `kanata --check` 를 돌리므로 문법 오류는 서비스가 아니라 리빌드에서 걸린다.
# 비상 탈출: 왼쪽 Ctrl + Space + Esc 를 함께 누르면 kanata 가 끝난다(내장, 설정과 무관).
{ ... }:

{
  services.kanata = {
    enable = true;

    keyboards.default = {
      # Without this, keys no layer maps (x, z, …) bypass kanata's state
      # machine, so tap-hold-press on Caps cannot see them as the other key
      # that commits the hold.
      #
      # 장치는 kanata 가 고른다: 키 1–115 중 하나라도 있으면 키보드로 본다(kanata src/oskbd/linux.rs
      # has_keyboard_keys). 볼륨 키를 가진 장치도 걸리는데, 잡히면 kanata 는 키 이벤트만 다시 내보내서
      # 그 장치의 스위치 이벤트(덮개, 태블릿 모드, SW_HEADPHONE_INSERT)가 조용히 사라진다. 그런 장치는
      # 이름(/proc/bus/input/devices 의 N:)으로 뺀다. 새 기계에서는
      #     journalctl -u kanata-default -b | grep -E 'registering|excluded'
      # subline-check 의 격리 키보드(~/git/subline crates/check/src/uinput.rs)를 잡으면 그 키가 kanata 의
      # 가상 키보드로 지금 세션에 들어가고 시험은 키를 못 받아 실패한다.
      extraDefCfg = ''
        process-unmapped-keys yes
        linux-dev-names-exclude (
          "subline-check isolated keyboard"
          "subline-check isolated usb keyboard"
          "gpio-keys"
        )
      '';

      # The base layer must come before nav.kbd: the first layer defined is
      # the one kanata starts in.
      #
      # Right Alt goes out as KEY_HANGEUL (122) for fcitx5-hangul, which binds
      # the Hangul keysym (./korean.nix, Hotkey/TriggerKeys). kanata has no
      # Linux name for 122 — `kana` is KEY_KATAKANAHIRAGANA there (kanata
      # parser/src/keys/mod.rs) — so it is named here by code.
      config = ''
        (deflocalkeys-linux
          hngl 122
        )

        (deflayermap (base)
          caps @caps
          lsft @sl
          rsft @sr
          ralt hngl
        )

        ${builtins.readFile ../shared/kanata/nav.kbd}
      '';
    };
  };
}
