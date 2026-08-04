#!/bin/sh
#
# 포커스된 컬럼을 화면 가득 채우고, 다시 누르면 원래 폭으로 되돌린다 (Alt+M).
#
# ── 왜 스크립트인가 ───────────────────────────────────────────────────────
# rift 에는 maximise 명령이 없다. column_width_ratio 는 레이아웃을 만들 때만
# 읽히므로 설정을 고쳐도 이미 떠 있는 컬럼은 안 변한다. 남는 건 resize-by 로
# 살아 있는 폭을 밀어 주는 것뿐이고, 그건 상대값이라 "지금 커져 있나"를 누군가
# 기억해야 한다. 그 기억이 $STATE 파일이다.
#
# 창 단위로 기억하는 게 요점이다. 키운 창을 그대로 두고 다른 창으로 갔다가
# 돌아오면 여전히 커져 있고, 다른 창에서 Alt+M 을 누르면 그 창이 새로 커진다 —
# 전역 불린 하나로는 이 둘을 구분할 수 없다.

RIFT="/opt/homebrew/bin/rift-cli"
STATE="${TMPDIR:-/tmp}/rift-monocle-window"

command -v jq >/dev/null 2>&1 || exit 0
[ -x "$RIFT" ] || exit 0

# 설정에서 폭의 양 끝을 읽어 온다. 하드코딩하면 rift.toml 을 고칠 때마다 여기도
# 고쳐야 하고, 그 어긋남은 "가끔 화면을 다 못 채운다"로만 드러난다.
cfg="$(timeout 3 "$RIFT" execute config get 2>/dev/null)"
base="$(printf '%s' "$cfg" | jq -r '.settings.layout.scrolling.column_width_ratio // empty')"
max="$(printf '%s' "$cfg" | jq -r '.settings.layout.scrolling.max_column_width_ratio // empty')"
base="${base:-0.5}"
max="${max:-1.0}"

focused="$(timeout 3 "$RIFT" query workspaces 2>/dev/null |
	jq -r '.[] | select(.is_active) | .windows[] | select(.is_focused) | .window_server_id' |
	head -1)"
[ -z "$focused" ] && exit 0

prev="$(cat "$STATE" 2>/dev/null)"

if [ "$focused" = "$prev" ]; then
	# 이미 키워 둔 그 창이다. 줄이는 쪽으로 같은 크기만큼 되돌린다.
	# `--` 는 뒤따르는 음수를 옵션으로 읽지 않게 한다.
	delta="$(awk -v m="$max" -v b="$base" 'BEGIN { printf "%.4f", -1 * (m - b) }')"
	"$RIFT" execute window resize-by -- "$delta" >/dev/null 2>&1
	rm -f "$STATE"
else
	delta="$(awk -v m="$max" -v b="$base" 'BEGIN { printf "%.4f", m - b }')"
	"$RIFT" execute window resize-by -- "$delta" >/dev/null 2>&1
	printf '%s' "$focused" >"$STATE"
fi
