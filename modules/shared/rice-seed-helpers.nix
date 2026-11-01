# home.activation 에 펼쳐 쓰는 rice_sync·rice_ensure — 라이싱 파일을 $HOME 에 쓰기 가능한 시드로 심는다.
# 판정은 기준선(../../apps/rice/baseline.sh, 판정표는 그 머리말)이 한다. 전체 그림: docs/rice-seeding.md
''
  . ${../../apps/rice/baseline.sh}

  rice_sync() { # rice_sync <store-source> <destination>
    # local 을 안 쓴다 — 함께 펼쳐지는 baseline.sh 를 sh 로 도는 apps/ 스크립트도 읽으므로 POSIX 안에 둔다.
    src="$1"; dst="$2"; rel="''${2#"$HOME"/}"

    if [ ! -e "$dst" ]; then
      $DRY_RUN_CMD mkdir -p "$(dirname "$dst")"
      $DRY_RUN_CMD cp -R "$src" "$dst"
      # Store paths are read-only; the whole point is a writable copy.
      $DRY_RUN_CMD chmod -R u+w "$dst"
      rice_baseline_record "$dst"
      echo "seeded ~/$rel"
      return 0
    fi

    # 기준선이 없으면 라이브에서 잡고 멈춘다 — 손 안 댄 척 라이브를 덮는 게 제일 나쁜 실패다.
    if ! rice_baseline_has "$dst"; then
      rice_baseline_record "$dst"
      if ! diff -rq "$src" "$dst" >/dev/null 2>&1; then
        echo "note: ~/$rel 이 레포와 다르다. 기준선만 잡았다 —"
        echo "      맞추려면 apps/rice/restore (레포→라이브) 또는 apps/rice/save (라이브→레포)"
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

    # 양쪽 다 기준선에서 벗어났으면 어느 쪽을 밀어도 상대 변경이 사라지므로 사람이 고른다.
    if ! diff -rq "$src" "$(rice_baseline_path "$dst")" >/dev/null 2>&1; then
      echo "conflict: ~/$rel 은 라이브와 레포가 **둘 다** 기준선에서 벗어났다."
      echo "          아무것도 안 했다. apps/rice/save --check 로 라이브 쪽 변경을 먼저 볼 것"
    fi
    return 0
  }

  # 배선 줄(include 등)만 보장한다. 없으면 스위처는 도는데 화면만 안 바뀐다.
  rice_ensure() { # rice_ensure <file> <line> <comment>
    [ -f "$1" ] || return 0
    grep -qxF "$2" "$1" && return 0
    $DRY_RUN_CMD printf '\n%s\n%s\n' "$3" "$2" >> "$1"
    echo "wired $2 into $1"
  }
''
