# home.activation 스크립트에 붙여 쓰는 셸 함수 두 개. 라이싱 파일을 $HOME 에
# 심는 모듈들이 공유한다 — ../nixos/niri (니리·fuzzel·GTK), ../nixos/hyprland
# (hyprland.lua·셰이더·스튜디오), ../nixos/dms (플러그인), ./ghostty (터미널),
# ../darwin/rice (rift·karabiner 등) 다섯이다.
#
#   ''
#     ${import ../shared/rice-seed-helpers.nix}
#     rice_sync ${./something} "$HOME/.config/something"
#   ''
#
# ── rice_sync: 기준선을 보고 가른다 ───────────────────────────────────────
# 이 레포의 라이싱 파일은 Nix 가 관리하지 않는다. 스토어 심볼릭 링크로 두면
# 읽기 전용이 되어 니리가 핫리로드할 여지가 없고, DMS 설정 GUI 는 원자적 교체
# (임시 파일 + rename)로 쓰기 때문에 링크가 첫 저장에 평범한 파일로 바뀐다.
# 그래서 레포는 원본이 아니라 한쪽 끝이고, 되받아 저장하는 건 apps/rice-save 다.
#
# 어느 쪽을 밀지는 기준선(../../apps/rice-baseline.sh)이 가른다. 네 경우의 판정표는
# 그 파일 머리말에 있고, 요점은 둘이다:
#
#   라이브가 기준선과 같다   = 손 안 댔다는 **증명** → 레포 것으로 갱신해도 안전
#   라이브가 기준선과 다르다 = 저장 안 한 작업이 있다 → 안 건드린다
#
# 존재 여부만 보던 시절에는 아래쪽만 있었고, 그래서 레포에 새로 넣은 것이 이미
# 설정을 가진 머신에 영영 안 들어갔다. rice_ensure 와 모듈들의 sed 마이그레이션이
# 전부 그 구멍을 줄 단위·패턴 단위로 메우려던 것이다.
#
# ── 부트스트랩은 밀어넣지 않는다 ──────────────────────────────────────────
# 기준선이 없는 머신에서는 라이브에서 기준선을 잡고 **거기서 멈춘다.** 레포와
# 다르면 그 사실만 알린다. 손 안 댄 척하며 라이브를 통째로 덮는 것이 제일 나쁜
# 실패 모드라, 그 한 번은 사람이 고르게 둔다 — apps/rice-restore 로 밀어넣거나
# apps/rice-save 로 되받거나.
#
# ── rice_ensure: 배선 한 줄만 보장한다 ────────────────────────────────────
# 판정표 4행(양쪽 다 고침)에서 rice_sync 는 일부러 아무것도 안 한다. 그런데
# include 같은 배선 줄은 없으면 기능 전체가 죽고, 증상이 "스위처는 성실히
# 동작하는데 화면만 안 바뀐다"라 원인 찾기가 제일 나쁘다. 그래서 파일 내용이
# 아니라 그 줄이 있는지만 보고, 없을 때만 덧붙인다 — 손으로 한 리싱은 안 덮는다.
#
# 스위처들도 각자 같은 일을 한 번 더 한다(apps/rice-lib.sh 의 rice_ensure_line)
# — 리빌드 없이 고쳐지도록.
#
# 덧붙이면 라이브가 기준선에서 벗어나므로 그 다음 apps/rice-save 는 이 파일을
# 되받는다. 배선 줄은 레포에도 이미 있으니 diff 에는 안 뜬다.
''
  . ${../../apps/rice-baseline.sh}

  rice_sync() { # rice_sync <store-source> <destination>
    # local 을 안 쓴다. 이 문자열은 activation 스크립트 안에 그대로 펼쳐지고,
    # ../../apps/rice-baseline.sh 는 sh 로 도는 apps/ 스크립트들도 읽는다 —
    # 양쪽에서 같은 모양이려면 POSIX 안에 있는 편이 낫다.
    src="$1"; dst="$2"; rel="''${2#"$HOME"/}"

    # 없으면 그냥 심는다. 기준선도 여기서 처음 잡힌다.
    if [ ! -e "$dst" ]; then
      $DRY_RUN_CMD mkdir -p "$(dirname "$dst")"
      $DRY_RUN_CMD cp -R "$src" "$dst"
      # Store paths are read-only; the whole point is a writable copy.
      $DRY_RUN_CMD chmod -R u+w "$dst"
      rice_baseline_record "$dst"
      echo "seeded ~/$rel"
      return 0
    fi

    # 기준선이 없는 머신 — 라이브에서 잡고 멈춘다(위 머리말).
    if ! rice_baseline_has "$dst"; then
      rice_baseline_record "$dst"
      if ! diff -rq "$src" "$dst" >/dev/null 2>&1; then
        echo "note: ~/$rel 이 레포와 다르다. 기준선만 잡았다 —"
        echo "      맞추려면 apps/rice-restore (레포→라이브) 또는 apps/rice-save (라이브→레포)"
      fi
      return 0
    fi

    if rice_baseline_same "$dst"; then
      # 라이브는 손 안 댔다. 레포가 움직였으면 따라간다.
      if ! diff -rq "$src" "$dst" >/dev/null 2>&1; then
        $DRY_RUN_CMD rm -rf "$dst"
        $DRY_RUN_CMD cp -R "$src" "$dst"
        $DRY_RUN_CMD chmod -R u+w "$dst"
        rice_baseline_record "$dst"
        echo "updated ~/$rel (레포 변경 반영)"
      fi
      return 0
    fi

    # 라이브가 기준선에서 벗어나 있다. 레포도 같이 움직였으면 말해 준다 —
    # 어느 쪽을 밀어도 상대의 변경이 사라지는 자리라 사람이 골라야 한다.
    if ! diff -rq "$src" "$(rice_baseline_path "$dst")" >/dev/null 2>&1; then
      echo "conflict: ~/$rel 은 라이브와 레포가 **둘 다** 기준선에서 벗어났다."
      echo "          아무것도 안 했다. apps/rice-save --check 로 라이브 쪽 변경을 먼저 볼 것"
    fi
    return 0
  }

  rice_ensure() { # rice_ensure <file> <line> <comment>
    [ -f "$1" ] || return 0
    grep -qxF "$2" "$1" && return 0
    $DRY_RUN_CMD printf '\n%s\n%s\n' "$3" "$2" >> "$1"
    echo "wired $2 into $1"
  }
''
