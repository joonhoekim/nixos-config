# 라이싱 스크립트 — 저장과 복원

`apps/rice/` 의 셸 스크립트 가운데 라이브 ↔ 레포를 오가는 것(save, restore)의 쓰는 법과 세부. 나머지(스위처 공통부,
기준선, 터미널 룩)는 [rice-tools.md](rice-tools.md).

`nix run .#rice-<이름>` 으로도 부를 수 있지만, 라이싱 중에는 체크아웃의 `apps/rice/<이름>` 을 직접 부른다(스크립트를
고칠 때마다 rebuild 하지 않게).

## apps/rice/save — 라이브 → 레포

라이싱 파일은 Nix 가 관리하지 않는 보통의 쓰기 가능한 파일이다 — 앱이 저장 즉시 다시 읽고, 손으로 고친 것이 리빌드에
덮이지 않게([rice-seeding](rice-seeding.md)). save 는 그 짝으로, 레포 사본은 백업이자 다음 머신의 시드이고 사람이 말할
때만 갱신된다.

흐름: `~/.config` 에서 고친다 → 라이브로 확인 → `apps/rice/save` → `git diff` → 커밋.

### 옵션

- `--check` — 검증하고 무엇이 다른지만 보고, 아무것도 안 쓴다.

### 기준선

"레포와 다르면 되받는다"는 방향을 못 가린다. 레포에만 더한 것(다른 머신에서 온 커밋, 손으로 쓴 주석)도 "다름"이라, 라이브를
손도 안 댄 파일이 되받기 한 번에 레포에서 지워진다. 그래서 `baseline.sh` 의 기준선을 함께 본다
([rice-tools.md](rice-tools.md#기준선baseline--appsricebaselinesh)). 라이브가 기준선과 같으면 아무도 라이브를 안 고쳤다는
증명이므로 "레포가 앞섬"이라고만 말하고, 맞추는 건 `apps/rice/restore` 나 리빌드의 몫이다.

### 안 받는 것과 이유

- `~/.config/ghostty/rice.conf`, `~/.config/rice/term` — rice-term 이 `rices/` 에서 복사한 것. 터미널 룩은 `rices/` 를 고친다.
- `~/.config/ghostty/themes/` — 레포의 `themes/dankcolors` 는 시드 팔레트이고 레포에서 직접 고친다.

## apps/rice/restore — 레포 → 라이브

save 의 반대 방향이다. 평소에는 필요 없다 — 레포를 먼저 고친 흔한 경우(다른 머신에서 가져온 커밋, git 에서 되돌린 변경)는
리빌드의 `rice_sync` 가 기준선을 보고 라이브가 손 안 닿았으면 알아서 따라간다([rice-seeding](rice-seeding.md)). restore 는
rice_sync 가 일부러 손 떼는 자리를 위한 것이다: 라이브를 손댔는데 레포 것으로 덮고 싶을 때, 양쪽이 다 움직여 conflict 로
멈춘 뒤 레포 쪽을 고를 때, 리빌드를 기다리지 않고 지금 밀어 넣을 때. 즉 "사람이 레포를 고른다"는 명령이다.

### 쓰는 법

```sh
apps/rice/restore                 # 전부
apps/rice/restore ghostty wezterm # 고른 것만
apps/rice/restore --check         # 무엇이 덮이는지만 보고 아무것도 안 쓴다
apps/rice/restore --yes           # 확인을 묻지 않는다 (키 바인딩·스크립트용)
```

### 대상

rice-save 가 저장하는 것과 정확히 같은 집합이어야 한다. 한쪽만 고치면 왕복이 안 맞는다.

| 대상 | 내용 | 플랫폼 |
|---|---|---|
| ghostty | config, rices/, shaders/ | 양쪽 |
| wezterm | wezterm.lua | macOS |
| rift-grid | config.toml (키맵) | macOS |
| linearmouse | linearmouse.json (마우스 휠 방향) | macOS |
| helpers | rift-grid 키바인딩이 부르는 스크립트들 (rice/bin) | macOS |

플랫폼은 여기서만 가린다(uname). save 는 라이브가 없으면 "skip (absent)" 로 비켜 가지만, 방향이 반대인 restore 는 원본이
레포에 늘 있어 그대로 두면 리눅스에 macOS 설정을 심는다.

ghostty 의 `themes/` 는 뺐다. save 도 저장하지 않는다.

### 백업

덮기 전의 것은 `~/.config/rice/backups/<UTC 시각>/` 에 그 자리 그대로 쌓인다. 스크립트는 지우지 않는다 — 되돌릴 일은
대개 한참 뒤에 생기고, 텍스트 파일 몇 개라 무게가 없다. 정리는 그 디렉터리를 지우면 된다.

### 복원 뒤 다시 읽히기

대상 디렉터리를 `rm -rf` 뒤 `cp` 하므로 감시가 걸려 있던 아이노드가 사라진다. 그래서 대상마다 명시적으로 다시 읽힌다:

- ghostty → 켜 둔 룩으로 `apps/rice/term` 을 다시 돌린다(rice.conf 를 다시 만들고 reload-config 를 보낸다)
- rift-grid → `rift-grid-cli execute config reload`
- LinearMouse → JSON 검사 뒤 `launchctl kickstart`
- wezterm 은 디렉터리를 통째로 감시해 알아서 다시 읽고, helpers 는 키마다 새로 실행되는 스크립트라 할 일이 없다.
