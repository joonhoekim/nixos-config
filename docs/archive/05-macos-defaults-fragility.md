# 05. macOS defaults의 취약성과 리스크

> **보관본** — 지금 `docs/` 세 편으로 압축되기 전의 원본이다. 파일 경로·앱 목록 등
> 세부는 그 시점의 레포를 서술하므로 현재와 다르다. 현행 문서는 [`../README.md`](../README.md)부터.

Apple은 macOS를 마음대로 바꿀 수 있다. 스크립트 해석을 바꾸거나, 노출했던 경로를 막을 수도 있다.
이 문제가 실제로 얼마나 자주, 얼마나 깊게 일어났는가.

## 결론부터: 빈도 "높음", 깊이 "보통" (전면 폐기는 아직 없음)

깨짐은 두 종류로 나뉘며, 빈도와 깊이가 다르다.

- (A) key 표류 — 개별 설정 key가 이름이 바뀌거나 사라지거나 무력화됨
  - 빈도: 잦음 (거의 매년). 깊이: 얕음. 증상: 토글 하나가 조용히 안 먹음.
- (B) 메커니즘 변경 — `defaults`/plist가 동작하는 방식 자체가 바뀜
  - 빈도: 드묾 (몇 년에 한 번). 깊이: 깊음. 증상: 전체 자동화가 흔들림.

## 역사적 랜드마크

### 2018 — Mojave (10.14): 가장 깊은 메커니즘 변경

"해석 정의를 바꾼" 대표 사례. `cfprefsd`라는 데몬이 환경설정을 메모리에 캐싱하면서,
`defaults write`로 plist를 직접 바꿔도 cfprefsd가 옛 값으로 덮어써버리는 일이 생겼다.
게다가 Full Disk Access(TCC) 권한이 없으면 터미널이 일부 설정을 읽지도 못하게 막혔다.
"파일에 쓰면 적용된다"는 전제 자체가 흔들린 사건.

### 2022 — Ventura (13): System Settings 전면 재작성

환경설정 앱을 iPad 스타일로 통째로 갈아엎으면서 수많은 preference key가 제거·이동됐다 —
`com.apple.preference.mouse`(Mouse 창 자체가 사라짐), Energy Saver, Extensions 등.
기존 AppleScript 자동화가 대량으로 깨졌고, nix-darwin도 이 시기에
"재부팅 후 `/run/current-system`이 사라지는" 버그를 겪었다.

### 2024~ — Sonoma/Sequoia (14/15): 계속되는 key 표류

nix-darwin 이슈 트래커를 보면 Sequoia(15.1)에서 스크린세이버 설정, 다중 유저 적용,
일부 trackpad 설정이 "적용은 됐다고 나오는데 실제론 안 먹는" 문제들이 보고된다.
전면 붕괴는 아니지만 개별 설정이 조용히 무력화되는 전형적 패턴.

### 상시 — 즉시 반영 안 됨

깨짐까지는 아니어도, 많은 설정이 로그아웃/재시작이나 `killall Dock` 전에는 반영되지 않는다.
cfprefsd 캐싱의 부작용이다.

## 왜 전면 폐기는 안 일어났나 (그리고 당분간 안 할 듯)

"어느 날 노출부를 막아버릴 수도 있다"는 우려는 타당하지만, 구조적으로 그러기 어려운 이유가 있다.

- Apple 자신이 이 기반에 의존한다. System Settings 앱, 엔터프라이즈 MDM, Configuration Profile 전부
  같은 cfprefsd/plist 위에서 돌아간다. 이걸 없애면 자기 OS가 부서진다.
  그래서 `defaults`/plist 메커니즘은 10.9(2013)부터 십수 년째 살아남았다.
- 대신 Apple은 권장 경로를 따로 민다 — `defaults write`(비공식, 자기 책임)가 아니라
  Configuration Profile(`.mobileconfig`) / MDM(공식, 잠금 가능)이다.

핵심: `defaults`는 Apple이 "안정적 설정 API"라고 약속한 적이 없는 반(半)비공식 표면이다.
nix-darwin은 그 위에 올라타 있다. 통째로 막힐 확률은 낮지만, 개별 key는 보장이 없다.

## 실전적 함의

- 매 메이저 OS 업그레이드 후, 일부 `system.defaults`가 조용히 안 먹을 수 있다.
  에러도 안 나고 그냥 무시되는 게 흔하다. 업그레이드 직후엔 중요한 설정이 실제 반영됐는지 눈으로 확인하자.
- 이것은 nix-darwin만의 문제가 아니라 `defaults`를 쓰는 모든 도구(수동 스크립트, AppleScript,
  다른 dotfile 매니저)의 공통 리스크다. nix-darwin은 오히려 커뮤니티가 깨진 key를 빠르게 패치하는 편이라
  혼자 스크립트를 짜는 것보다 안전망이 있다.
- 정말 절대 안 바뀌어야 할 설정(보안 정책 등)은 `system.defaults`보다 Configuration Profile이 더 견고하다 —
  Apple 공식 경로라서. nix-darwin도 일부 profile을 지원한다.
- 패키지(`/nix/store`) 쪽은 이 리스크와 무관하다. CLI 도구·홈브루·dotfile은 Apple 환경설정과 상관없이 잘 돈다.
  흔들리는 것은 어디까지나 `system.defaults`(macOS 환경설정) 부분뿐이다.

## 한 줄 요약

"전면 차단"은 거의 없지만 "개별 key가 조용히 깨지는" 것은 사실상 매년 일어난다.
`defaults`는 Apple이 보장하지 않은 반비공식 표면이라 그렇다.
단, Apple 자신이 이 기반에 의존하므로 메커니즘 자체가 사라질 가능성은 낮고,
nix-darwin 커뮤니티가 보통 빠르게 따라잡는다.

## 출처

- [eclecticlight — Working safely with preferences in Mojave (cfprefsd 캐싱)](https://eclecticlight.co/2019/08/22/working-safely-and-effectively-with-preferences-in-mojave/)
- [eclecticlight — How Preferences do and don't work](https://eclecticlight.co/2023/07/28/how-preferences-do-and-dont-work/)
- [nix-darwin #1207 — System defaults not applied properly nor globally (Sequoia)](https://github.com/nix-darwin/nix-darwin/issues/1207)
- [nix-darwin #1148 — config not loaded after reboot on Ventura](https://github.com/nix-darwin/nix-darwin/issues/1148)
- [osxdaily — System Settings in Ventura/Sonoma](https://osxdaily.com/2022/11/29/finding-system-preferences-using-system-settings-in-macos-ventura/)
- [Gordon Beeming — Locking Down macOS Settings (Configuration Profiles)](https://gordonbeeming.com/blog/2025-11-22/locking-down-macos-settings-the-real-way)
