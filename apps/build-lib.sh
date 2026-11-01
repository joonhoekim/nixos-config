# build 와 build-switch 가 source 하는 프롤로그. 끝나면 $target·$arch·$passthru 가 서고 "$@" 는 비어 있다
# (sourced 파일의 shift 는 부르는 쪽 인자를 먹는다). `nix run` 아래서 $0 옆에 있다는 전제는 rice/lib.sh 와 같다.

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

# `[ ] && ...` 로 쓰면 리눅스에서 거짓일 때 종료값 1 이 sh -e 인 부르는 쪽을 그 자리에서 죽인다.
arch="$(uname -m)"
if [ "$arch" = "arm64" ]; then arch="aarch64"; fi

# hosts/<플랫폼>/ 의 디렉토리가 곧 호스트다(flake.nix 의 hostDirs). nix eval 로 물으면 input 을
# 다 받아야 해서 첫 빌드 전에는 몇 분 걸린다.
repo="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

host_list() {  # <플랫폼>
  find "$repo/hosts/$1" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | sed 's|.*/||' | sort
}
has_host() {   # <플랫폼> <이름>
  host_list "$1" | grep -qx "$2"
}

if [ "$(uname)" = "Darwin" ]; then
  # 이 Mac 전용 디렉토리가 있으면 그쪽, 없으면 arch 로 키잉한 공용 설정(flake.nix).
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
  # 설치 직후 hostname 이 'nixos' 면 nix 는 "flake output attribute ... does not exist" 만 뱉으므로 여기서 목록과 함께 멈춘다.
  if ! has_host nixos "$target"; then
    printf "${RED}nixosConfigurations.%s 가 없다.${NC}\n" "$target" >&2
    printf "있는 호스트: %s\n" "$(host_list nixos | tr '\n' ' ')" >&2
    printf "${DIM}→ --host NAME 으로 고르거나, 이 기계가 처음이면 ./apps/setup 을 돌린다.${NC}\n" >&2
    exit 1
  fi
fi
