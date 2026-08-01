# rice 프로필

한 프로필 = 룩 하나. `apps/rice-switch <name>` 으로 전환하고, 반영은 즉시다 —
재시작도 리빌드도 없다. niri 는 `config.kdl` 과 그것이 include 한 파일까지
감시하고, DMS 는 `settings.json` 에 `watchChanges` 가 걸려 있기 때문이다
(`Common/SettingsData.qml`).

## 파일 두 개

| 파일 | 대상 | 방식 |
|---|---|---|
| `niri.kdl` | `~/.config/niri/profile.kdl` | 통째로 교체 |
| `dms.json` | `~/.config/DankMaterialShell/settings.json` | jq 오버레이 병합 |

DMS 만 오버레이인 이유: `settings.json` 에는 룩과 무관한 머신 상태(디스플레이
프로필, 위젯 사용 기록 등)가 섞여 있어서, 통째로 갈아끼우면 그것까지 날아간다.
그래서 레포에는 `settings.json` 전체를 두지 않는다 — 새 머신에서는 DMS 가 자기
기본값을 쓰고, 그 위에 프로필이 얹힌다.

`dms.json` 의 구조:

- `settings` — `settings.json` 최상위에 병합
- `bar` — `barConfigs` 의 **각 항목**에 병합. jq 의 `*` 는 배열을 통째로 교체해
  버리므로 최상위 병합에 섞을 수 없다. 모니터마다 바를 여러 개 둔 설정에서도
  전부 같은 룩이 되도록 항목별로 병합한다.

터미널(ghostty)은 프로필에 조각이 없다. DMS/matugen 이 써 주는
`~/.config/ghostty/themes/dankcolors` 를 읽으므로 색은 이미 따라온다. 형태는
`../ghostty/config` 가 기본값을 정하고, 그 위에 `apps/rice-term` 이 고른
`../ghostty/rices/<name>.conf` 가 얹힌다 — 그건 프로필과 **독립된 축**이라
프로필을 바꿔도 터미널 룩은 그대로 남는다. 자세한 건 `../ghostty/README.md`.

## 지켜야 할 규칙

**세 프로필이 같은 키 집합을 다룬다.** 한쪽에만 있는 키가 생기면 A→B→A 로
돌아왔을 때 원래 값으로 안 돌아온다. 키를 추가할 때는 세 파일 모두에 넣는다.

**테마는 스톡 이름만 쓴다.** `StockThemes.js` 의 blue / purple / green / orange
/ red / cyan / pink / amber / coral / monochrome, 그리고 특수값 `dynamic`
(월페이퍼에서 matugen 으로 추출). `themes/` 에 받아 둔 레지스트리 테마는
`currentThemeName=custom` 으로 지정해도 **파일 쓰기만으로는 적용되지 않는다** —
실측으로 확인했다. 그런 테마는 설정 GUI 에서 고르고, 프로필은 그 위의
형태·투명도만 건드린다.

## 현재 프로필

| | amoled | frosted | matugen |
|---|---|---|---|
| 갭 / 곡률 | 6 / 6 | 14 / 16 | 10 / 12 |
| 테두리 | 보더 1px | 포커스링 2px | 보더 2px |
| 블러 | 없음 | 켬, 바 투명도 0.6 | 켬, 0.85 |
| 색 | monochrome | blue | 월페이퍼에서 추출 |

`matugen` 은 월페이퍼가 있어야 제 모습이 나온다 — `apps/rice-wall` 참고.

## 새 프로필 만들기

```sh
cp -r ~/.config/rice/profiles/amoled ~/.config/rice/profiles/mine
$EDITOR ~/.config/rice/profiles/mine/{niri.kdl,dms.json}
apps/rice-switch mine     # 바로 확인
apps/rice-save            # 마음에 들면 레포에 저장
```
