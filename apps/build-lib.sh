# build 와 build-switch 가 공유하는 부분. 실행 파일이 아니라 sourced 되는 조각이라
# flake 의 apps 목록에도 없다 — rice-lib.sh 와 같은 방식이고, `nix run` 아래서도
# $0 옆에 이 파일이 같이 있다는 전제도 같다(그쪽 머리말 참고).
#
#   . "$(dirname "$0")/build-lib.sh"
#
# 하는 일: --host 파싱($host 에 담고 나머지는 $passthru), NIXPKGS_ALLOW_UNFREE,
# 그리고 $arch (macOS 의 uname 은 arm64 라고 하는데 nix 어트리뷰트는 aarch64 다).
# sourced 파일 안의 shift 는 부르는 쪽의 인자에 그대로 걸리므로, 이 파일을 읽고
# 나면 "$@" 는 비어 있고 $passthru 만 남는다.
#
# 두 스크립트가 이 프롤로그를 바이트 단위로 똑같이 하나씩 들고 있었다 — 한쪽만
# 고쳐지는 날이 오기 전에 접었다.

GREEN='\033[1;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

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
