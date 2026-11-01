# 기준선: 라이싱 파일이 마지막으로 동기화된 내용. 레포·라이브와 견줘 누가 고쳤는지 가린다.
# save·restore 와 rice-seed-helpers.nix 가 같이 source 한다. 판정 규칙이 두 벌이면 한쪽만 고친 날 조용히 어긋난다.
# 전체 그림(세 상태 판정표, 자리, 거르개): docs/rice-tools.md

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
# 둘째 인자는 라이브 대신 견줄 내용(거른 뒤). 기준선이 없으면 다르다고 답한다.
rice_baseline_same() {
	_rb_base="$(rice_baseline_path "$1")"
	[ -e "$_rb_base" ] || return 1
	diff -rq "$_rb_base" "${2:-$1}" >/dev/null 2>&1
}

# rice_baseline_record <라이브 경로> [담을 내용]
# 둘째 인자는 라이브 대신 담을 내용. 되받기(save)와 밀어넣기(restore·rice_sync) 양쪽이 부른다.
rice_baseline_record() {
	_rb_base="$(rice_baseline_path "$1")"
	_rb_src="${2:-$1}"
	[ -e "$_rb_src" ] || return 0
	${DRY_RUN_CMD:-} mkdir -p "$(dirname "$_rb_base")"
	# rm 뒤 cp -R 이 GNU cp -T 와 같은 결과다. BSD cp 에는 -T 가 없고 이 파일은 macOS 에서도 돈다.
	${DRY_RUN_CMD:-} rm -rf "$_rb_base"
	${DRY_RUN_CMD:-} cp -R "$_rb_src" "$_rb_base"
	${DRY_RUN_CMD:-} chmod -R u+w "$_rb_base"
}
