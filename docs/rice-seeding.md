# 라이싱 파일 시드 — rice_sync / rice_ensure

"라이싱(ricing)"은 데스크톱의 룩(색, 셰이더, 바, 터미널 모양)을 손보는 일이다. 이 저장소에서 라이싱 파일은 Nix 가 관리하는
읽기 전용 파일이 아니라 `~/.config` 의 쓰기 가능한 보통 파일이고, 레포는 그 시드를 들고 있다. 시드를 언제 심고 언제 손을
떼는지는 `modules/shared/rice-seed-helpers.nix` 의 셸 함수 둘이 정한다.

쓰는 모듈: `modules/nixos/niri`(니리·fuzzel·GTK), `modules/nixos/hyprland`(hyprland.lua·셰이더·스튜디오),
`modules/nixos/dms`(플러그인), `modules/shared/ghostty`(터미널), `modules/darwin/rice`(rift-grid·wezterm 등).
home.activation 스크립트에 펼쳐 쓴다:

```nix
''
  ${import ../shared/rice-seed-helpers.nix}
  rice_sync ${./something} "$HOME/.config/something"
''
```

## 왜 스토어 심링크가 아닌가

스토어 심볼릭 링크는 읽기 전용이라 니리 같은 컴포지터가 핫리로드할 편집 자체를 할 수 없고, DMS 설정 GUI 는 원자적
교체(임시 파일 + rename)로 쓰기 때문에 링크가 첫 저장에 평범한 파일로 바뀐다. 그래서 레포는 원본이 아니라 한쪽 끝이고,
라이브에서 레포로 되받는 건 `apps/rice/save`, 레포에서 라이브로 미는 건 `apps/rice/restore` 다
([rice-scripts.md](rice-scripts.md)).

## rice_sync: 기준선을 보고 가른다

판정은 기준선(`apps/rice/baseline.sh`, [rice-tools.md](rice-tools.md#기준선baseline--appsricebaselinesh)의 판정표)이
한다. 요점:

- 라이브 == 기준선: 손 안 댔다는 증명 → 레포가 움직였으면 레포 것으로 갱신해도 안전하다.
- 라이브 != 기준선: 저장 안 한 작업이 있다 → 안 건드린다. 레포도 기준선에서 벗어났으면(양쪽 다 고침) 어느 쪽을 밀어도 상대
  변경이 사라지므로 conflict 를 알리고 사람이 고른다(`apps/rice/save --check` 로 라이브 쪽 변경을 먼저 본다).

존재 여부만 보면 레포에 새로 넣은 것이 이미 설정을 가진 머신에 영영 안 들어간다. 기준선이 그 구멍을 막는다.

## 부트스트랩은 밀어넣지 않는다

기준선이 없는 머신에서는 라이브에서 기준선을 잡고 거기서 멈춘다. 레포와 다르면 그 사실만 알린다. 손 안 댄 척하며 라이브를
통째로 덮는 것이 제일 나쁜 실패 모드라, 그 한 번은 사람이 고른다 — `apps/rice/restore`(레포→라이브) 또는
`apps/rice/save`(라이브→레포).

## rice_ensure: 배선 한 줄만 보장한다

판정표 4행(양쪽 다 고침)에서 rice_sync 는 일부러 아무것도 안 한다. 그런데 include 같은 배선 줄은 없으면 기능 전체가 죽고,
증상이 "스위처는 성실히 동작하는데 화면만 안 바뀐다"라 원인 찾기가 제일 나쁘다. 그래서 파일 내용이 아니라 그 줄이 있는지만
보고(`grep -qxF`), 없을 때만 덧붙인다 — 손으로 한 라이싱은 안 덮는다.

스위처들도 각자 같은 일을 한 번 더 한다(`apps/rice/lib.sh` 의 `rice_ensure_line`) — 리빌드 없이 고쳐지도록.

덧붙이면 라이브가 기준선에서 벗어나므로 다음 `apps/rice/save` 는 그 파일을 되받는다. 배선 줄은 레포에도 이미 있으니 diff
에는 안 뜬다.

## 셸 제약

- 함수 안에서 `local` 을 쓰지 않는다. 이 문자열은 activation 스크립트에 그대로 펼쳐지고, 같이 source 하는
  `apps/rice/baseline.sh` 는 sh 로 도는 apps/ 스크립트들도 읽는다 — 양쪽에서 같은 모양이려면 POSIX 안에 있는 편이 낫다.
- 복사본에는 `chmod -R u+w` 를 준다. 스토어 경로는 읽기 전용이고, 쓰기 가능한 복사본이 요점이다.
