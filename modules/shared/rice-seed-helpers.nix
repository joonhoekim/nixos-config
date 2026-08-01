# home.activation 스크립트에 붙여 쓰는 셸 함수 두 개. 라이싱 파일을 $HOME 에
# 심는 모듈들이 공유한다 — 지금은 ../nixos/niri/default.nix (니리·fuzzel·GTK)와
# ./ghostty.nix (터미널) 둘이다.
#
#   ''
#     ${import ../shared/rice-seed-helpers.nix}
#     seed ${./something} "$HOME/.config/something"
#   ''
#
# ── seed: 없을 때만 복사한다 ──────────────────────────────────────────────
# 이 레포의 라이싱 파일은 Nix 가 관리하지 않는다. 스토어 심볼릭 링크로 두면
# 읽기 전용이 되어 니리가 핫리로드할 여지가 없고, DMS 설정 GUI 는 원자적 교체
# (임시 파일 + rename)로 쓰기 때문에 링크가 첫 저장에 평범한 파일로 바뀐다.
# 그래서 레포는 시드일 뿐이고, 첫 복사 뒤부터는 $HOME 쪽이 원본이다. 되받아
# 저장하는 건 apps/rice-save 다.
#
# 존재 검사가 그 규칙의 전부다: 이미 있는 설정은 절대 건드리지 않으므로,
# 리싱 도중에 리빌드를 해도 저장 안 한 작업이 날아가지 않는다.
#
# ── ensure: 배선 한 줄만 보장한다 ─────────────────────────────────────────
# seed 의 존재 검사에는 대가가 있다. 레포 시드에 줄을 새로 넣어도, 이미 그 파일을
# 가진 머신에는 영영 안 들어간다. 대부분은 상관없지만 include 같은 배선 줄은
# 기능 전체를 켜고 끄는 스위치라 얘기가 다르다 — 없으면 스위처가 성실히 동작하고
# 화면만 안 바뀌는, 원인 찾기 제일 나쁜 상태가 된다(실제로 한 번 겪었다).
#
# 그래서 파일 내용이 아니라 "그 줄이 있는지"만 본다. 없을 때만 덧붙이므로 손으로
# 한 리싱을 덮지 않는다는 원칙은 그대로다. 스위처들도 각자 같은 일을 한 번 더
# 한다(apps/rice-lib.sh 의 rice_ensure_line) — 리빌드 없이 고쳐지도록.
''
  seed() { # seed <store-source> <destination>
    [ -e "$2" ] && return 0
    $DRY_RUN_CMD mkdir -p "$(dirname "$2")"
    $DRY_RUN_CMD cp -rT "$1" "$2"
    # Store paths are read-only; the whole point is a writable copy.
    $DRY_RUN_CMD chmod -R u+w "$2"
    echo "seeded $2"
  }

  ensure() { # ensure <file> <line> <comment>
    [ -f "$1" ] || return 0
    grep -qxF "$2" "$1" && return 0
    $DRY_RUN_CMD printf '\n%s\n%s\n' "$3" "$2" >> "$1"
    echo "wired $2 into $1"
  }
''
