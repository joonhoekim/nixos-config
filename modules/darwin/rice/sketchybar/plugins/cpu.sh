#!/bin/sh
#
# CPU 사용률.
#
# `top -l 1` 대신 ps 로 뽑는다. top 은 한 번 돌 때 샘플 간격만큼(기본 1초 이상)
# 붙잡혀 있고, 이 스크립트는 10초마다 돈다 — 바를 그리는 데 1초를 쓰는 건 너무
# 비싸다. ps 쪽은 프로세스별 누적 평균이라 순간값과 정확히 같지는 않지만,
# "지금 바쁜가"를 보는 용도에는 충분하다.
#
# 코어 수로 나눈다. ps 의 %cpu 는 코어당 100% 이라, 안 나누면 M 시리즈에서
# 태연히 400% 가 나온다.

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
# shellcheck source=../colors.sh
. "$CONFIG_DIR/colors.sh"

cores="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 1)"
usage="$(ps -A -o %cpu | awk -v c="$cores" '{ s += $1 } END { printf "%d", s / c }')"

if [ "$usage" -ge 80 ]; then color="$CRIT_COLOR"
elif [ "$usage" -ge 50 ]; then color="$WARN_COLOR"
else color="$ICON_COLOR"
fi

sketchybar --set "$NAME" icon.color="$color" label="$usage%"
