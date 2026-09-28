# build 와 build-switch 가 공유하는 부분. 실행 파일이 아니라 sourced 되는 조각이라
# flake 의 apps 목록에도 없다 — rice/lib.sh 와 같은 방식이고, `nix run` 아래서도
# $0 옆에 이 파일이 같이 있다는 전제도 같다(그쪽 머리말 참고).
#
#   . "$(dirname "$0")/build-lib.sh"
#
# 하는 일: --host 파싱($host 에 담고 나머지는 $passthru), NIXPKGS_ALLOW_UNFREE,
# $arch (macOS 의 uname 은 arm64 라고 하는데 nix 어트리뷰트는 aarch64 다), 그리고
# **$target** — 실제로 빌드할 설정 이름. sourced 파일 안의 shift 는 부르는 쪽의
# 인자에 그대로 걸리므로, 이 파일을 읽고 나면 "$@" 는 비어 있고 $passthru 만 남는다.
#
# 두 스크립트가 이 프롤로그를 바이트 단위로 똑같이 하나씩 들고 있었다 — 한쪽만
# 고쳐지는 날이 오기 전에 접었다.

GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; DIM='\033[2m'; NC='\033[0m'

host=""; passthru=""
while [ $# -gt 0 ]; do
  case "$1" in
    --host=*) host="${1#*=}"; shift ;;
    --host)   host="$2"; shift 2 ;;
    *)        passthru="$passthru $1"; shift ;;
  esac
done

export NIXPKGS_ALLOW_UNFREE=1

# `[ ... ] && ...` 꼴이 아닌 것에 이유가 있다: 두 스크립트 다 sh -e 로 돌고,
# 리눅스에서는 이 검사가 거짓이라 && 사슬의 종료값 1 이 스크립트를 그 자리에서
# 죽인다. 원본에서는 이 줄이 Darwin 분기 안에만 있어서 안 드러났던 함정이다.
arch="$(uname -m)"
if [ "$arch" = "arm64" ]; then arch="aarch64"; fi

# ── 어떤 설정을 빌드할 것인가 ────────────────────────────────────────────
# hosts/<플랫폼>/ 아래의 디렉토리가 곧 호스트다 — flake.nix 의 hostDirs 와 같은
# 규칙이고, 그래서 nix 를 평가하지 않고도 목록을 안다. (`nix eval` 로 물어보면
# 답은 같지만 input 을 전부 받아 와야 해서, 첫 빌드 전에는 그게 곧 몇 분이다.)
repo="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

host_list() {  # <플랫폼>
  find "$repo/hosts/$1" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | sed 's|.*/||' | sort
}
has_host() {   # <플랫폼> <이름>
  host_list "$1" | grep -qx "$2"
}

if [ "$(uname)" = "Darwin" ]; then
  # 두 층이다(flake.nix 참고): 이 Mac 전용 디렉토리가 있으면 그쪽이 이기고,
  # 없으면 공용 설정(arch 로 키잉)으로 떨어진다.
  if [ -n "$host" ]; then
    target="$host"
  else
    lh="$(scutil --get LocalHostName 2>/dev/null || true)"
    if [ -n "$lh" ] && has_host darwin "$lh"; then target="$lh"; else target="${arch}-darwin"; fi
  fi
  if [ "$target" != "${arch}-darwin" ] && ! has_host darwin "$target"; then
    printf "${RED}darwinConfigurations.%s 가 없다.${NC}\n" "$target" >&2
    printf "이 Mac 전용 호스트: %s\n" "$(host_list darwin | tr '\n' ' ')" >&2
    printf "공용 호스트: %s\n" "${arch}-darwin" >&2
    printf "${DIM}→ --host 로 고르거나, 이 기계가 처음이면 ./apps/setup 을 돌린다.${NC}\n" >&2
    exit 1
  fi
else
  target="${host:-$(hostname)}"
  # 설치 직후에는 hostname 이 아직 'nixos' 라 여기서 걸린다. 그냥 두면 nix 가
  # "flake output attribute ... does not exist" 만 뱉고 끝나서, 뭘 해야 하는지가
  # 안 보인다.
  if ! has_host nixos "$target"; then
    printf "${RED}nixosConfigurations.%s 가 없다.${NC}\n" "$target" >&2
    printf "있는 호스트: %s\n" "$(host_list nixos | tr '\n' ' ')" >&2
    printf "${DIM}→ --host NAME 으로 고르거나, 이 기계가 처음이면 ./apps/setup 을 돌린다.${NC}\n" >&2
    exit 1
  fi
fi
