# opencode + oh-my-openagent

세 층으로 나뉜다.

| 층 | 어디서 | 누가 관리 |
|---|---|---|
| opencode 바이너리 | nixpkgs (`../packages.nix`) | Nix |
| oh-my-openagent 플러그인 | `~/.cache/opencode/packages/` | opencode 가 시작 시 설치 |
| 설정 두 파일 | `~/.config/opencode/opencode.json`, `~/.omo/omo.jsonc` | 이 모듈이 시드, 사람이 라이브에서 편집, `apps/rice-save` 로 되받음 |

## 왜 심링크가 아닌가

- `opencode.json`: 설치 TUI 가 `plugin` 항목을 쓴다. 읽기 전용이면 실패한다.
- `omo.jsonc`: 플러그인이 시작마다 설정 마이그레이션을 돌리고, 바뀌면 임시 파일 +
  `rename` 으로 덮어쓴다. 심링크는 첫 마이그레이션에 일반 파일이 되고, 다음
  `build-switch` 에서 home-manager 가 "관리 안 하는 파일이 있다"며 멈춘다.

`rice_sync` 는 기준선(`~/.local/state/rice/baseline`)을 보고 라이브를 손 안 댔을
때만 레포 것을 밀어넣으므로, 마이그레이션이 고쳐 쓴 파일은 리빌드가 덮지 않는다.
그 변경은 `apps/rice-save` 가 "라이브가 바뀜" 으로 잡아 준다. 커밋하면 정착.

## 플러그인 갱신은 핀을 올려서

opencode 의 플러그인 설치(`Npm.add`)는 지정자별로 캐시 디렉터리를 나누고,
디렉터리가 이미 있으면 재설치하지 않는다. 그래서:

- `"oh-my-openagent"` 나 `@latest` 로 적으면 처음 한 번 깔린 뒤 영영 갱신되지 않는다.
- `"oh-my-openagent@4.19.4"` 처럼 버전을 박으면 핀을 올릴 때마다 새 디렉터리에
  새로 깔린다. Nix 식으로 레포에서 버전을 정하는 셈이라 이쪽을 쓴다.

핀을 올리는 절차: `opencode.json` 의 버전을 고치고 → `apps/rice-restore opencode`
(또는 리빌드) → `opencode` 재실행. 옛 버전 디렉터리는 `~/.cache/opencode/packages/`
에 남으니 가끔 지운다. 최신 버전은 `npm view oh-my-openagent version`.

## 왕복하지 않는 것

- `~/.omo/` 의 나머지 전부 — `codegraph/`, `lsp-daemon/`, `run-continuation/`
  같은 런타임 상태, `omo.jsonc.bak.<시각>` 백업, 그리고 새 버전이 만들
  `omo.jsonc.migrations.json` 사이드카. 왕복은 `omo.jsonc` 한 파일만 한다.
  (4.19.4 는 적용한 마이그레이션을 사이드카 없이 파일 안 `_migrations` 에
  적는다. 그 줄은 되받아 커밋해도 된다 — 새 머신도 그걸 읽고 다시 안 돌린다.)
- `~/.local/share/opencode/auth.json` — provider 인증. `opencode auth login` 으로.
- `~/.cache/opencode/` — 플러그인 캐시.

## 새 머신

1. `nix run .#build-switch` — 바이너리와 두 시드가 깔린다.
2. `opencode auth login`.
3. `opencode` 한 번 실행 — 플러그인 다운로드와 마이그레이션. 인증 전에 띄우면
   플러그인은 깔리지만 에이전트가 고른 모델을 못 찾아 실패한다. 정상이다.
4. 마이그레이션이 omo.jsonc 를 고쳤으면 `apps/rice-save` 로 되받아 커밋.

## 처음 채울 때

`bunx oh-my-openagent install` 의 TUI 로 omo.jsonc 를 채우고(bun 은 mise 에 있다),
`apps/rice-save --check` 로 확인한 뒤 되받는다. 되받기 전에 키·토큰이 섞이지
않았는지 본다.
