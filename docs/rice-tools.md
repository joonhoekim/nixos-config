# 라이싱 도구 — 기준선, 스위처 공통부, 터미널 룩

`apps/rice/` 의 셸 스크립트 가운데 판정 기반(기준선·공통부)과 터미널 룩 스위처를 모은다. 저장/복원은
[rice-scripts.md](rice-scripts.md), 시드 규칙은 [rice-seeding.md](rice-seeding.md). macOS 의 `apps/rice/colors` 는
[macos-rice.md](macos-rice.md#appsricecolors).

## 기준선(baseline) — apps/rice/baseline.sh

라이싱 파일이 **마지막으로 동기화된 시점의 내용**을 따로 한 벌 보관해서, 레포와 라이브가 다를 때 "누가 고쳤나"를 답할 수
있게 한다.

쓰는 곳: `apps/rice/save`·`apps/rice/restore` 는 `. "$(dirname "$0")/baseline.sh"`, `modules/shared/rice-seed-helpers.nix`
는 `. ${../../apps/rice/baseline.sh}`. 두 자리에서 같은 파일을 읽는 것이 요점이다 — 판정 규칙이 두 벌이 되면 한쪽만 고친
날 조용히 어긋난다.

### 왜 필요한가

상태가 둘뿐이면(레포, 라이브) "다르다"는 알 수 있어도 누가 고쳤는지는 원리적으로 알 수 없다. 그러면 도구가 추측해야 하고
두 방향 모두 틀린다: 레포에만 더한 것은 이미 설정을 가진 머신에 영영 안 들어가고, 그 상태로 되받으면 라이브에 없는 그것이
레포에서 지워진다.

기준선이 있으면 상태가 셋이 된다:

| 라이브==기준선 | 레포==기준선 | 뜻 | 할 일 |
|---|---|---|---|
| O | O | 아무도 안 고침 | 아무것도 안 함 |
| O | X | 레포만 고침 | 라이브로 밀어넣기 (fast-forward) |
| X | O | 라이브만 고침 | 레포로 되받기 |
| X | X | 양쪽 다 고침 | 멈추고 알린다 |

라이싱 도중 리빌드를 해도 저장 안 한 작업이 안 날아간다 — 밀어넣기는 라이브가 손 안 닿았다고 증명됐을 때(2행)만 일어난다.

### 자리

`$XDG_STATE_HOME/rice/baseline` 아래에 대상 경로에서 `$HOME/` 만 뗀 모양 그대로 쌓는다(설정도 캐시도 아닌, 도구가 다음
판정을 하려고 들고 있는 상태라 state). 예: `~/.config/ghostty/config` →
`~/.local/state/rice/baseline/.config/ghostty/config`.

지워도 안전하다. 다음 리빌드가 라이브에서 다시 잡고(부트스트랩), 레포와 다르면 알려 준다. 잃는 것은 "누가 고쳤나"를 아는
능력 한 번뿐이다.

## 스위처 공통부 — apps/rice/lib.sh

스위처가 보이는 부분은 같다: 인자 없이 부르면 목록, `--next`
로 순환, 없는 이름이면 목록을 보여주며 거절. 그 공통부가 `lib.sh` 다.

- `. "$(dirname "$0")/lib.sh"` 로 읽는다. `nix run .#rice-term` 으로 돌 때도 이 경로가 맞는다: mkApp 이
  `exec ${self}/apps/<name>` 를 하므로 `$0` 이 스토어 안의 apps 디렉터리이고 형제 파일이 같이 들어 있다.
- 쓰는 쪽이 채울 것: `rice_kind`("룩"처럼 메시지에 들어갈 말), `rice_current_file`(현재 선택을 담은 파일),
  `rice_list()`(이름을 한 줄에 하나씩 정렬해 출력). 그리고 `rice_dispatch "$@"` 를 부르면 `RICE_NAME` 에 전환할 이름이
  담긴다. 목록 출력 같은 갈래는 거기서 처리하고 스크립트를 끝낸다(sourced 라 함수 안 exit 가 스크립트 전체를 끝낸다).
- 없는 이름이면 "그런 거 없다"만이 아니라 목록을 같이 보여준다.
- 배선 줄을 보장하는 `rice_ensure_line` 도 여기 있다([rice-seeding](rice-seeding.md#rice_ensure-배선-한-줄만-보장한다)).

## 터미널 룩 — apps/rice/term

```sh
apps/rice/term            # 현재 룩과 목록
apps/rice/term crt        # 전환
apps/rice/term --next
apps/rice/term off        # 셰이더 없는 기본 상태 — 탈출구
```

룩 하나 = `~/.config/ghostty/rices/<name>.conf` 조각 하나. 고른 조각을 `~/.config/ghostty/rice.conf` 로 복사하면 끝이다 —
config 끝의 `config-file = ?rice.conf` 가 그걸 읽고, ghostty 는 config-file 을 자기를 담은 파일보다 나중에 읽으므로 조각이
항상 본체를 이긴다. 셰이더 자체는 [ghostty-shaders.md](ghostty-shaders.md).

반영은 D-Bus 로 reload-config 액션을 보내서 한다. custom-shader 는 런타임에 바꿀 수 있는 키라 열린 창 전부에 즉시 적용된다.
손으로는 ctrl+shift+, 이고, ghostty 가 안 떠 있으면 다음에 뜰 때 읽는다. macOS 에서는 background-opacity 가 리로드로 안
바뀌어서(ghostty 문서) 셰이더는 바로 갈리는데 투명도만 그대로인 상태가 잠깐 보인다.

색은 조각이 아니라 `themes/dankcolors` 가 정한다. 셰이더 컴파일이 실패해 창이 새까매져도 이 스크립트는 다른 터미널에서
돌릴 수 있다.

## 배경화면 경로 — apps/rice/wallpaper-path.py

macOS 의 현재 데스크톱 배경화면 파일 경로를 찍는다. `apps/rice/colors`(인자 없이 불렀을 때)와
`modules/darwin/rice/default.nix` 의 wal-watch 에이전트가 같이 쓴다([macos-rice.md](macos-rice.md)).

- osascript 로 System Events 에 묻지 않는 이유: Automation 권한이 필요한데 LaunchAgent 에게는 그 권한 창이 뜨지 않아서,
  거부도 아닌 빈 문자열만 돌아오고 로그도 안 남는다. plist 는 자기 홈의 파일이라 권한이 필요 없다.
- 경로는 중첩된 바이너리 plist 안에 있어서 plutil 로 한 겹 벗겨도 base64 만 나온다. 그래서 바이트로 읽고 `file://` URL 을
  찾는다. URL 은 퍼센트 인코딩(`%20`, 한글은 `%ED%95%9C` 꼴)이라 풀어야 한다.
- macOS 기본 벽지(동적 벽지 등)는 파일이 아니라 URL 이 없다.
