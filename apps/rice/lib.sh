# 라이싱 스위처 공통부. sourced 조각이라 flake apps 목록에 없다.
# 쓰는 쪽이 rice_kind·rice_current_file·rice_list() 를 채우고 rice_dispatch "$@" 를 부르면 RICE_NAME 이 담긴다.
# 목록 출력 같은 갈래는 함수 안 exit 로 스크립트를 끝낸다(sourced 라서). 전체 그림: docs/rice-tools.md

GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; DIM='\033[2m'; NC='\033[0m'

rice_current() {
	[ -f "$rice_current_file" ] && cat "$rice_current_file" || echo "(unknown)"
}

rice_show() {
	cur="$(rice_current)"
	printf "현재: ${GREEN}%s${NC}\n" "$cur"
	rice_list | while read -r p; do
		[ "$p" = "$cur" ] && printf "  ${GREEN}* %s${NC}\n" "$p" || printf "    %s\n" "$p"
	done
}

rice_reject() {
	# "그런 %s가" 는 받침에 따라 조사가 틀어져서 목록 이름을 앞에 둔다.
	printf "${RED}%s 목록에 없는 이름이다: %s${NC}\n" "$rice_kind" "$1"
	rice_list | sed 's/^/  /'
	exit 1
}

rice_dispatch() {
	case "${1:-}" in
	"")
		rice_show
		exit 0
		;;
	--list | -l)
		rice_list
		exit 0
		;;
	--current | -c)
		rice_current
		exit 0
		;;
	--next | -n)
		# 현재값이 목록에 없으면 첫 번째.
		RICE_NAME="$(rice_list | awk -v cur="$(rice_current)" '
			{ a[NR] = $0; if ($0 == cur) hit = NR }
			END { print (hit ? a[hit % NR + 1] : a[1]) }')"
		;;
	-*)
		printf "${RED}알 수 없는 옵션: %s${NC}\n" "$1"
		exit 1
		;;
	*)
		RICE_NAME="$1"
		;;
	esac
}

# 시드는 파일이 없을 때만 복사해서, 시드에 새로 넣은 배선 줄은 기존 머신에 안 들어간다.
# 그러면 스위처는 성공하고 화면만 그대로다. 이미 있으면 아무 일도 안 한다.
rice_ensure_line() { # rice_ensure_line <file> <line> <comment>
	[ -f "$1" ] || return 0
	grep -qxF "$2" "$1" && return 0
	printf '\n%s\n%s\n' "$3" "$2" >>"$1"
	printf "${DIM}  %s 에 %s 를 붙였다 (시드 이후에 생긴 배선)${NC}\n" "$1" "$2"
}
