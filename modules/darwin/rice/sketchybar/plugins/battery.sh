#!/bin/sh
#
# 배터리. `pmset -g batt` 한 줄에서 퍼센트와 충전 상태를 뽑는다.
#
# 데스크톱(Mac mini 등)에는 배터리가 없어서 pmset 이 퍼센트를 안 내놓는다.
# 그때는 아이템을 숨긴다 — 0% 로 그리면 고장난 것처럼 보인다.

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
# shellcheck source=../colors.sh
. "$CONFIG_DIR/colors.sh"

batt="$(pmset -g batt 2>/dev/null)"
pct="$(printf '%s' "$batt" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')"

if [ -z "$pct" ]; then
	sketchybar --set "$NAME" drawing=off
	exit 0
fi

charging=false
case "$batt" in
*'AC Power'*) charging=true ;;
esac

if [ "$charging" = true ]; then
	icon="󰂄"
	color="$OK_COLOR"
else
	# Nerd Font 배터리 글리프는 10칸이라 퍼센트를 그대로 못 쓴다.
	if [ "$pct" -ge 90 ]; then icon="󰁹"
	elif [ "$pct" -ge 70 ]; then icon="󰂀"
	elif [ "$pct" -ge 50 ]; then icon="󰁾"
	elif [ "$pct" -ge 30 ]; then icon="󰁻"
	else icon="󰁺"
	fi

	if [ "$pct" -le 10 ]; then color="$CRIT_COLOR"
	elif [ "$pct" -le 25 ]; then color="$WARN_COLOR"
	else color="$ICON_COLOR"
	fi
fi

sketchybar --set "$NAME" \
	drawing=on \
	icon="$icon" \
	icon.color="$color" \
	label="$pct%"
