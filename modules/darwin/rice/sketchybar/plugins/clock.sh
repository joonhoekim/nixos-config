#!/bin/sh
#
# 시계. 24시간제 + 요일은 hosts/darwin/default.nix 의 menuExtraClock 설정과 같은
# 취향이다(macOS 메뉴바 시계를 계속 쓰는 경우를 위해 둘을 맞춰 둔다).

sketchybar --set "$NAME" label="$(date '+%a %d %b  %H:%M')"
