#!/bin/sh
# 포커스된 컬럼을 화면 가득 채우고, 다시 누르면 원래 폭으로 되돌린다 (Alt+R).
# rift-grid 엔 maximise 가 없고 column_width_ratio 는 레이아웃을 만들 때만 읽힌다. resize-by 는 상대값이라
# 어느 창을 키웠는지 $STATE 에 창 단위로 기억한다(전역 불린으로는 창을 오가면 어긋난다).

CLI="$HOME/.local/bin/rift-grid-cli"
STATE="${TMPDIR:-/tmp}/rift-grid-monocle-window"

command -v jq >/dev/null 2>&1 || exit 0
[ -x "$CLI" ] || exit 0

# 설정에서 폭의 양 끝을 읽어 온다. 하드코딩하면 rift-grid.toml 을 고칠 때마다 여기도
# 고쳐야 하고, 그 어긋남은 "가끔 화면을 다 못 채운다"로만 드러난다.
cfg="$(timeout 3 "$CLI" execute config get 2>/dev/null)"
base="$(printf '%s' "$cfg" | jq -r '.settings.layout.scrolling.column_width_ratio // empty')"
max="$(printf '%s' "$cfg" | jq -r '.settings.layout.scrolling.max_column_width_ratio // empty')"
base="${base:-0.5}"
max="${max:-1.0}"

focused="$(timeout 3 "$CLI" query workspaces 2>/dev/null |
	jq -r '.[] | select(.is_active) | .windows[] | select(.is_focused) | .window_server_id' |
	head -1)"
[ -z "$focused" ] && exit 0

prev="$(cat "$STATE" 2>/dev/null)"

if [ "$focused" = "$prev" ]; then
	# 이미 키워 둔 창이면 같은 크기만큼 되돌린다. `--` 는 뒤의 음수를 옵션으로 읽지 않게 한다.
	delta="$(awk -v m="$max" -v b="$base" 'BEGIN { printf "%.4f", -1 * (m - b) }')"
	"$CLI" execute window resize-by -- "$delta" >/dev/null 2>&1
	rm -f "$STATE"
else
	delta="$(awk -v m="$max" -v b="$base" 'BEGIN { printf "%.4f", m - b }')"
	"$CLI" execute window resize-by -- "$delta" >/dev/null 2>&1
	printf '%s' "$focused" >"$STATE"
fi
