#!/bin/sh
#
# 포커스된 앱. front_app_switched 이벤트일 때만 $INFO 에 앱 이름이 들어 있고,
# 그 외(첫 그리기, --reload 직후)에는 비어 있다 — 그때는 건드리지 않는다.
# 빈 문자열로 --set 하면 라벨이 사라져서 리로드할 때마다 칸이 깜빡인다.

[ -z "$INFO" ] && exit 0

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
# shellcheck source=../icon_map.sh
. "$CONFIG_DIR/icon_map.sh"

__icon_map "$INFO"

sketchybar --set "$NAME" icon="$icon_result" label="$INFO"
