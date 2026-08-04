#!/bin/sh
#
# 현재 입력 소스. 한/영이 지금 어느 쪽인지 화면에 있는 것과 없는 것의 차이가 커서
# 넣었다 — macOS 는 이걸 메뉴바 입력 메뉴를 켜야만 보여 준다.
#
# ── 왜 폴링인가 ───────────────────────────────────────────────────────────
# sketchybar 에는 입력기 전환 이벤트가 없다. macOS 는 그 사실을
# NSTextInputContext 의 distributed notification 으로만 알리는데 셸에서 잡을
# 방법이 없다. 그래서 2초마다 `defaults read` 를 한 번 한다 — cfprefsd 가 이미
# 메모리에 들고 있는 도메인이라 디스크를 치지 않는다.
#
# ── 값의 모양 (여기가 함정이다) ───────────────────────────────────────────
# 입력기(IME)와 키보드 레이아웃은 *다른 키로* 기록된다. 같은 배열의 항목인데
# 필드 구성이 아예 다르다:
#
#   한글:  { "Bundle ID" = "com.apple.inputmethod.Korean";
#            "Input Mode" = "com.apple.inputmethod.Korean.2SetKorean";
#            InputSourceKind = "Input Mode"; }
#
#   영문:  { InputSourceKind = "Keyboard Layout";
#            "KeyboardLayout ID" = 252;
#            "KeyboardLayout Name" = ABC; }
#
# 영문 쪽에는 "com.apple.keylayout.ABC" 같은 번들 ID가 아예 없다. 그런 게 있다고
# 보고 패턴을 짜면 영문일 때만 조용히 안 맞는다 — 한글은 맞으니 반쯤 동작해서
# 더 헷갈린다. 그래서 키를 뽑지 않고 문자열 전체를 본다.
#
# 전환은 이 레포가 F18 로 배선해 뒀다(hosts/darwin/default.nix 의
# AppleSymbolicHotKeys 61번). 여기는 표시만 한다.

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
# shellcheck source=../colors.sh
. "$CONFIG_DIR/colors.sh"

raw="$(defaults read com.apple.HIToolbox AppleSelectedInputSources 2>/dev/null)"

# IME 를 먼저 본다. 한글 입력 중에는 레이아웃 이름이 문자열에 안 들어오므로
# 순서가 실제로 중요하지는 않지만, 판정이 좁은 쪽부터 두는 편이 안전하다.
case "$raw" in
*inputmethod.Korean*)
	label="한"
	color="$ACCENT_ALT"
	;;
*inputmethod.Japanese* | *Kotoeri*)
	label="あ"
	color="$ACCENT_ALT"
	;;
*ABC* | *"U.S."*)
	label="EN"
	color="$LABEL_COLOR"
	;;
*)
	# 읽기는 됐는데 아는 모양이 아니다. 빈칸보다는 뭔가 띄워 두는 게 낫다.
	label="??"
	color="$DIM_COLOR"
	;;
esac

sketchybar --set "$NAME" icon="󰌌" icon.color="$color" label="$label" label.color="$color"
