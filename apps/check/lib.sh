# apps/check/ 가 source 하는 조각. 판정은 apps/doctor 와 같다: bad 가 하나라도 있으면 종료 1, warn 만이면 0.

GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; DIM='\033[2m'; NC='\033[0m'

warns=0; bads=0
ok()      { printf "  ${GREEN}✓${NC} %s\n" "$1"; }
warn()    { printf "  ${YELLOW}⚠${NC} %s\n" "$1"; warns=$((warns+1)); }
bad()     { printf "  ${RED}✗${NC} %s\n" "$1"; bads=$((bads+1)); }
hint()    { printf "      ${DIM}%s${NC}\n" "$1"; }
section() { printf "\n${YELLOW}%s${NC}\n" "$1"; }

# `nix run` 아래서는 $0 가 스토어의 레포 사본(flake.nix 가 있는 온전한 소스)이라 마지막 후보로 쓴다.
find_repo() {
  repo="${NIXOS_CONFIG_REPO:-}"
  [ -n "$repo" ] || repo="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$repo" ] || [ ! -e "$repo/flake.nix" ]; then
    repo="$(CDPATH= cd -- "$(dirname -- "$0")/../.." 2>/dev/null && pwd)"
  fi
  [ -e "$repo/flake.nix" ]
}

summary() {
  printf "\n"
  if [ "$bads" -gt 0 ]; then
    printf "${RED}깨진 것 %d개${NC}, 봐둘 것 %d개\n" "$bads" "$warns"
    exit 1
  fi
  if [ "$warns" -gt 0 ]; then
    printf "${YELLOW}봐둘 것 %d개.${NC} 깨진 것은 없다.\n" "$warns"
    exit 0
  fi
  printf "${GREEN}이상 없음.${NC}\n"
}
