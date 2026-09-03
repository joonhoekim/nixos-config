# 기준선(baseline). 라이싱 파일이 **마지막으로 동기화된 시점의 내용**을 따로
# 한 벌 보관해서, 레포와 라이브가 다를 때 "누가 고쳤나"를 답할 수 있게 한다.
#
#   . "$(dirname "$0")/rice-baseline.sh"        (apps/rice-save · apps/rice-restore)
#   . ${../../apps/rice-baseline.sh}            (modules/shared/rice-seed-helpers.nix)
#
# 두 자리에서 같은 파일을 읽는 것이 요점이다. 판정 규칙이 두 벌이 되면 한쪽만
# 고친 날 조용히 어긋나고, 그건 이 파일이 없애려는 문제 그 자체다.
#
# ── 왜 필요한가 ────────────────────────────────────────────────────────────
# 상태가 둘뿐이면(레포, 라이브) "다르다"는 알 수 있어도 **누가 고쳤는지는
# 원리적으로 알 수 없다.** 그래서 도구가 추측을 해야 하고, 두 방향 모두 틀린다:
# 레포에만 더한 것은 이미 설정을 가진 머신에 영영 안 들어가고, 그 상태로
# 되받으면 라이브에 없는 그것이 레포에서 지워진다.
#
# 기준선이 있으면 상태가 셋이 되고 질문이 답 가능해진다:
#
#   라이브==기준선  레포==기준선   뜻                 할 일
#   ─────────────  ────────────  ─────────────────  ────────────────────────
#        O              O        아무도 안 고침      아무것도 안 함
#        O              X        레포만 고침         라이브로 밀어넣기 (fast-forward)
#        X              O        라이브만 고침       레포로 되받기
#        X              X        양쪽 다 고침        멈추고 알린다
#
# "리싱 도중 리빌드를 해도 저장 안 한 작업이 안 날아간다"는 그대로다 — 밀어넣기는
# 라이브가 손 안 닿았다고 *증명*됐을 때(2행)만 일어난다.
#
# ── 어디에 두나 ────────────────────────────────────────────────────────────
# $XDG_STATE_HOME/rice/baseline 아래에, 대상 경로에서 $HOME/ 만 뗀 모양 그대로
# 쌓는다. 설정도 캐시도 아니고 "도구가 다음 판정을 하려고 들고 있는 상태"라
# state 가 맞는 자리다.
#
#   ~/.config/hypr/hyprland.lua
#     → ~/.local/state/rice/baseline/.config/hypr/hyprland.lua
#
# 지워도 안전하다. 다음 리빌드가 라이브에서 다시 잡고(부트스트랩), 레포와 다르면
# 알려 준다. 잃는 것은 "누가 고쳤나"를 아는 능력 한 번뿐이다.
#
# ── 거르개(filter) ─────────────────────────────────────────────────────────
# 몇몇 파일은 라이브에만 있는 파생 줄을 달고 산다(fuzzel.ini 맨 위의 include —
# apps/rice-fuzzel 이 이 머신의 절대 경로로 붙인다). 그걸 그대로 담으면 스위처가
# 한 번 돌 때마다 "라이브가 바뀌었다"가 되어 판정이 무의미해진다. 그래서 기준선에는
# **비교에 쓰는 형태**(거른 뒤)를 담는다. rice-save 와 rice-restore 가 이미 같은
# 거르개를 비교에 쓰므로 규칙이 하나로 맞는다.

rice_baseline_root() {
	printf '%s/rice/baseline' "${XDG_STATE_HOME:-$HOME/.local/state}"
}

# rice_baseline_path <라이브 경로>
rice_baseline_path() {
	printf '%s/%s' "$(rice_baseline_root)" "${1#"$HOME"/}"
}

# rice_baseline_has <라이브 경로> — 기준선이 잡혀 있나
rice_baseline_has() {
	[ -e "$(rice_baseline_path "$1")" ]
}

# rice_baseline_same <라이브 경로> [비교용 내용]
#
# 두 번째 인자를 주면 그것을 라이브 대신 견준다(거르개를 통과시킨 임시 파일).
# 기준선이 없으면 "같지 않다"로 답한다 — 부트스트랩은 부르는 쪽이 가른다.
rice_baseline_same() {
	_rb_base="$(rice_baseline_path "$1")"
	[ -e "$_rb_base" ] || return 1
	diff -rq "$_rb_base" "${2:-$1}" >/dev/null 2>&1
}

# rice_baseline_record <라이브 경로> [담을 내용]
#
# 두 번째 인자를 주면 라이브 대신 그것을 담는다. 방향이 어느 쪽이든 "이제부터
# 여기가 같은 지점"이라고 못 박는 일이므로, 되받기(rice-save)와 밀어넣기
# (rice-restore·rice_sync) 양쪽이 다 부른다.
rice_baseline_record() {
	_rb_base="$(rice_baseline_path "$1")"
	_rb_src="${2:-$1}"
	[ -e "$_rb_src" ] || return 0
	${DRY_RUN_CMD:-} mkdir -p "$(dirname "$_rb_base")"
	# rm 을 앞에 두면 `cp -R` 만으로 GNU 의 `-T` 와 같은 결과가 난다. macOS 의
	# BSD cp 에는 -T 가 없고 이 파일은 양쪽에서 돈다(modules/darwin/rice 도 쓴다).
	${DRY_RUN_CMD:-} rm -rf "$_rb_base"
	${DRY_RUN_CMD:-} cp -R "$_rb_src" "$_rb_base"
	${DRY_RUN_CMD:-} chmod -R u+w "$_rb_base"
}
