#!/bin/sh
#
# 워크스페이스 칸 아홉 개를 한 번에 칠한다.
#
# ── 왜 rift 에 다시 물어보나 ──────────────────────────────────────────────
# rift 가 --trigger 에 실어 보내는 RIFT_WORKSPACE_NAME 을 그대로 쓰지 않는다.
# 그 값은 *전환이 일어난 순간*에만 존재하기 때문이다. sketchybar 가 rift 보다
# 늦게 뜨거나 --reload 를 하면 아무 이벤트도 안 왔으므로 어느 칸도 못 칠한다.
# 예전 판은 그래서 "시작할 때 1번을 켜 두고 시작"하는 꼼수를 갖고 있었고, 실제로
# 다른 워크스페이스에 있으면 첫 전환 전까지 틀린 칸이 켜져 있었다.
#
# 그래서 이벤트는 "다시 물어보라"는 신호로만 쓰고, 진짜 상태는 rift 에서 읽는다.
# 기동 순서와 무관해지고, window_count 까지 같이 오므로 빈 워크스페이스를 숨길 수
# 있다.
#
# ── 왜 아이템 하나가 아홉 칸을 다 칠하나 ──────────────────────────────────
# 칸마다 script 를 달면 이벤트 한 번에 아홉 번 돌고, 아홉 번 다 rift 에 물어본다.
# 이 스크립트는 sketchybarrc 의 숨은 아이템(rift_spaces) 하나에만 걸려 있고,
# --set 을 전부 모아 sketchybar 를 한 번만 부른다.

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
# shellcheck source=../colors.sh
. "$CONFIG_DIR/colors.sh"

# brew formula 라서 nix 쪽 PATH 에 없다. sketchybarrc 의 같은 주석 참고.
RIFT_CLI="/opt/homebrew/bin/rift-cli"

# rift 가 어떤 이유로든 응답을 안 하면(재시작 중, 접근성 권한 대기 중) 여기서
# 영영 매달릴 수 있다. sketchybar 는 이벤트마다 이 스크립트를 부르므로 매달린
# 프로세스가 쌓인다. 3초면 정상 응답에는 차고 넘친다.
json="$(timeout 3 "$RIFT_CLI" query workspaces 2>/dev/null)"

# rift 가 아직 안 떴다. 칸을 지우지 말고 그냥 나간다 — 마지막으로 알던 상태를
# 남겨 두는 편이, 잠깐 전부 사라졌다가 돌아오는 것보다 눈에 덜 거슬린다.
[ -z "$json" ] && exit 0

active="$(printf '%s' "$json" | jq -r '.[] | select(.is_active) | .name')"

# "이름:창개수" 한 줄씩. 이름에 공백이 없다는 전제인데, rift.toml 의
# workspace_names 를 이 레포가 정하므로("1".."9") 안전하다.
batch=""
for row in $(printf '%s' "$json" | jq -r '.[] | "\(.name):\(.window_count)"'); do
	name="${row%%:*}"
	count="${row##*:}"

	if [ "$name" = "$active" ]; then
		batch="$batch --set space.$name drawing=on label.color=$ACCENT background.color=$ITEM_BG"
	elif [ "$count" -gt 0 ]; then
		# 창은 있지만 지금 보고 있지 않은 곳. 흐리게 두되 존재는 보인다.
		batch="$batch --set space.$name drawing=on label.color=$LABEL_COLOR background.color=$TRANSPARENT"
	else
		# 빈 워크스페이스는 아예 숨긴다. 아홉 칸을 늘 그려 두면 대부분이 죽은
		# 숫자라 눈이 그냥 흘려 보낸다.
		batch="$batch --set space.$name drawing=off"
	fi
done

# 색 값에 공백이 없어서 eval 로 풀어도 안전하고, 이렇게 해야 sketchybar 호출이
# 한 번으로 끝난다.
# shellcheck disable=SC2086
[ -n "$batch" ] && eval sketchybar $batch
