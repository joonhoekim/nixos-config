#!/bin/sh
#
# 바 전체가 쓰는 팔레트. sketchybarrc 와 plugins/* 가 각자 이 파일을 source 한다.
#
# 색을 여기서 정하지는 않는다. pywal 이 ~/.cache/wal/colors.sh 에 써 둔 16색을
# 읽어 sketchybar 가 이해하는 0xAARRGGBB 로 옮길 뿐이다. 그래서 월페이퍼를
# 바꾸면(apps/rice-colors) 바 색이 따라온다.
#
# 폴백이 있는 이유: 새 머신은 `wal` 을 한 번도 안 돌린 상태다. 그때 색이 비면
# sketchybar 는 에러를 내는 대신 검정으로 그려서, "바가 안 뜬다"처럼 보인다.
# 아래 기본값은 catppuccin mocha 계열이고, 첫 rice-colors 실행 때 덮인다.

WAL="$HOME/.cache/wal/colors.sh"
# shellcheck disable=SC1090
[ -f "$WAL" ] && . "$WAL"

background="${background:-#1e1e2e}"
foreground="${foreground:-#cdd6f4}"
color0="${color0:-#45475a}"
color1="${color1:-#f38ba8}"
color2="${color2:-#a6e3a1}"
color3="${color3:-#f9e2af}"
color4="${color4:-#89b4fa}"
color5="${color5:-#cba6f7}"
color6="${color6:-#94e2d5}"
color7="${color7:-#bac2de}"
color8="${color8:-#585b70}"

# '#rrggbb' + 알파 두 자리 -> 0xAARRGGBB.
# pywal 은 '#' 이 붙은 6자리로 쓰고 sketchybar 는 알파가 앞에 오는 8자리만 받는다.
argb() { printf '0x%s%s' "$2" "${1#\#}"; }

BAR_COLOR=$(argb "$background" e6)      # 살짝 비치게 — 완전 불투명이면 벽지가 죽는다
BAR_BORDER=$(argb "$color8" 40)

ITEM_BG=$(argb "$color0" 66)
LABEL_COLOR=$(argb "$foreground" ff)
ICON_COLOR=$(argb "$color4" ff)
DIM_COLOR=$(argb "$color8" ff)

ACCENT=$(argb "$color4" ff)             # 현재 워크스페이스, 포커스된 것
ACCENT_ALT=$(argb "$color5" ff)         # 앱 이름
OK_COLOR=$(argb "$color2" ff)           # 배터리 충전 중
WARN_COLOR=$(argb "$color3" ff)
CRIT_COLOR=$(argb "$color1" ff)

TRANSPARENT="0x00000000"

# 폰트. modules/shared/fonts.nix 가 등록하는 것 중에서 고른다 — 여기 없는 이름을
# 쓰면 macOS 가 조용히 다른 얼굴로 대체해서 아이콘이 네모로 뜬다.
FONT_TEXT="JetBrainsMono Nerd Font"
FONT_ICON="JetBrainsMono Nerd Font"
