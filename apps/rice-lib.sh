# 라이싱 스위처들이 공유하는 부분. 실행 파일이 아니라 sourced 되는 조각이라
# flake 의 apps 목록에도 없다.
#
#   . "$(dirname "$0")/rice-lib.sh"
#
# `nix run .#rice-switch` 로 돌 때도 이 경로가 맞는다. mkApp 이
# `exec ${self}/apps/<name>` 를 하므로 $0 이 스토어 안의 apps 디렉터리이고,
# 형제 파일이 같이 들어 있다 — rice-switch 와 rice-wall 이 rice-fuzzel 을
# 부르는 방식과 같은 전제다.
#
# 스위처는 축마다 다르지만(프로필은 디렉터리, 터미널 룩은 .conf 파일) 사용자에게
# 보이는 부분은 같아야 한다: 인자 없이 부르면 목록, --next 로 순환, 없는 이름이면
# 목록을 보여주며 거절. 그 공통부가 여기 있다.
#
# 쓰는 쪽에서 채워야 할 것:
#
#   rice_kind          "프로필" 처럼 메시지에 들어갈 말
#   rice_current_file  현재 선택을 담아 둔 파일 경로
#   rice_list()        고를 수 있는 이름을 한 줄에 하나씩, 정렬해서 출력
#
# 그리고 rice_dispatch "$@" 를 부르면 RICE_NAME 에 전환할 이름이 담겨 돌아온다.
# 목록 출력 같은 건 거기서 처리하고 스크립트를 끝내 버린다 — sourced 라서
# 함수 안의 exit 가 스크립트 전체를 끝낸다.

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

# 없는 이름이면 목록을 보여주고 끝낸다. 오타를 냈을 때 "그런 거 없다"만 듣는 것보다
# 뭐가 있는지 같이 보는 편이 낫다.
rice_reject() {
	# "그런 %s가" 로 쓰면 받침에 따라 조사가 틀어진다. 목록 이름을 앞에 두면
	# 조사를 고를 일이 없다.
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
		# 목록을 한 바퀴 돌려 현재 다음 것을 고른다. 현재값이 목록에 없으면 첫 번째.
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

# 파일 끝에 줄 하나를 보장한다. 이미 있으면 아무 일도 안 한다.
#
# 필요한 이유: 니리 모듈의 seed 는 파일이 *없을 때만* 복사한다. 그래서 이 레포의
# 시드 파일에 배선 줄을 새로 넣어도, 이미 설정이 있는 머신에는 영영 안 들어간다.
# 그러면 스위처는 성실히 동작하고 아무것도 안 바뀌는, 원인 찾기 제일 나쁜 상태가
# 된다. rice-fuzzel 이 자기 include 줄에 대해 같은 일을 한다.
rice_ensure_line() { # rice_ensure_line <file> <line> <comment>
	[ -f "$1" ] || return 0
	grep -qxF "$2" "$1" && return 0
	printf '\n%s\n%s\n' "$3" "$2" >>"$1"
	printf "${DIM}  %s 에 %s 를 붙였다 (시드 이후에 생긴 배선)${NC}\n" "$1" "$2"
}
