# 모바일 · 실기기 검증 도구

데스크톱에서 도는 검증 도구([`browser-tooling.md`](browser-tooling.md))는 **폰에
닿지 못한다**. 이 문서는 그 빈틈 — 실기기의 브라우저/앱을 보고 조작하는 도구들이다.
선언은 `modules/shared/packages.nix`의 "Mobile / on-device web verification" 절과
`modules/darwin/packages.nix`의 iOS 절에 있다.

---

## 무엇이 있나

| 도구 | 한 줄 | 플랫폼 |
|---|---|---|
| `android-tools` | adb + fastboot | shared |
| `scrcpy` | Android 화면 미러링·조작 | shared |
| `qrencode` | 터미널 QR — URL을 폰으로 | shared |
| `watchman` | RN/Metro가 기대하는 파일 워처 | shared (선제) |
| `maestro` | 모바일 E2E 플로우 | shared (선제) |
| `bundletool` | AAB ↔ APK 변환 | shared (선제) |
| `cocoapods` 외 5종 | iOS 네이티브 툴체인 | **darwin 전용** |

"선제(ahead-of-need)"는 지금 당장 쓰는 게 아니라, 첫 RN/모바일 프로젝트가
시작될 때 셋업 없이 바로 돌게 미리 선언해 둔 것들이다.

---

## adb — PWA 실기기 디버깅의 핵심

모바일 도구처럼 보이지만 실제로는 **웹/PWA 검증의 빈 조각**이다. 폰의 Chrome을
데스크톱 DevTools로 열고, 폰이 로컬 개발 서버를 보게 만드는 것 둘 다 adb가 한다.

```sh
# 연결 (USB 디버깅 켠 상태)
adb devices                          # 기기 목록 — 첫 연결은 폰에서 승인 필요

# 무선 연결 (Android 11+, 같은 Wi-Fi)
adb pair 192.168.0.x:port            # 폰의 "무선 디버깅 > 페어링 코드" 화면 값
adb connect 192.168.0.x:port
```

**폰 Chrome을 DevTools로 열기**: 데스크톱 Chrome에서 `chrome://inspect` →
연결된 기기의 탭 목록이 뜨고, 콘솔·네트워크·Lighthouse까지 전부 실기기 대상으로
돌릴 수 있다. PWA의 서비스워커·설치 배너·푸시는 에뮬레이션과 실기기가 다르게
행동하는 대표 영역이라 이 경로가 정답이다.

**폰에서 localhost 열기**: 터널 없이 USB로 포트를 뒤집는다.

```sh
adb reverse tcp:3000 tcp:3000        # 폰의 localhost:3000 → 이 기계의 :3000
```

폰 브라우저에서 그냥 `http://localhost:3000`을 열면 된다. secure context가
필요한 API(서비스워커 등)도 localhost는 예외라 HTTPS 없이 동작한다.

---

## scrcpy — 폰 화면을 데스크톱에서

adb 위에서 돈다. 미러링만이 아니라 마우스·키보드로 조작까지 된다.

```sh
scrcpy                               # 연결된 기기 미러링
scrcpy --record demo.mp4             # 시연 녹화
scrcpy --stay-awake --turn-screen-off  # 폰 화면은 끄고 데스크톱에서만
```

---

## qrencode — URL을 폰으로 넘기는 한 줄

cloudflared 터널 URL 같은 긴 임시 주소를 폰에 타이핑하는 마찰 제거.

```sh
qrencode -t ansiutf8 "https://random-words.trycloudflare.com"
# 터미널에 QR이 그려진다 — 폰 카메라로 스캔
```

터널 띄우기와 묶으면: [`local-https-proxy.md`](local-https-proxy.md)의
cloudflared 절 참고.

---

## 선제 선언분 — 언제 꺼내 쓰나

- **watchman** — React Native의 Metro 번들러가 파일 감시에 기대는 데몬.
  RN 프로젝트를 여는 순간부터 쓰인다 (없으면 Metro가 경고 + 느린 폴링).
- **maestro** — YAML로 플로우를 쓰는 모바일 E2E. Playwright의 모바일 대응물.
  시뮬레이터/에뮬레이터 대상. `maestro studio`로 셀렉터를 잡고
  `maestro test flow.yaml`로 돌린다.
- **bundletool** — 스토어 배포 형식(AAB)을 로컬 설치용 APK로 변환
  (`bundletool build-apks`). 배포 단계 전까지는 쓸 일 없음.

---

## iOS 네이티브 (darwin 전용)

`modules/darwin/packages.nix`에 있다 — nixpkgs에서 darwin 전용이라 shared에
넣으면 NixOS 평가가 깨진다 (drvPath 평가로 확인).

| 도구 | 용도 |
|---|---|
| `cocoapods` | RN/Flutter iOS 빌드가 여전히 요구 (SPM이 거기까진 못 옴) |
| `xcbeautify` | `xcodebuild ... \| xcbeautify` — 읽을 수 있는 빌드 로그 |
| `ios-deploy` | 실기기에 설치·디버그 (RN CLI가 내부적으로 사용) |
| `xcodes` | Xcode 버전 설치·전환 CLI |
| `swiftformat` / `swiftlint` | Swift 포매터/린터 |

**Xcode 본체는 nix로 못 깐다** — App Store 또는 `xcodes install`. iOS
시뮬레이터의 웹 디버깅은 macOS Safari의 개발자 메뉴(Develop > Simulator)로
연결한다 — adb/chrome://inspect의 Safari판.

---

## 안 넣은 것과 이유

- **Android SDK / Android Studio** — SDK는 Android Studio가 관리하는 게
  현실적이다 (macOS: homebrew cask, NixOS: 필요해지면 해당 호스트에
  `android-studio` 패키지). JDK는 mise, gradle은 프로젝트 wrapper — 언어
  런타임을 base에 안 까는 이 레포 원칙 그대로.
- **flutter** — nixpkgs에 있지만 프로젝트별 버전 민감도가 높아 fvm/mise 영역.
- **fastlane** — 관례상 프로젝트별 Gemfile/bundler로 고정하는 도구(플러그인·버전
  이 프로젝트 상태의 일부)라 전역 설치가 역행.
- **PWA 감사 도구 (lighthouse/workbox/web-push)** — npm 생태계라 `npx`.
  lighthouse는 nixpkgs에서 `meta.broken`이기도 하다
  ([`browser-tooling.md`](browser-tooling.md) "안 넣은 것" 절).
- **libimobiledevice / ideviceinstaller** — Linux에서 iOS 기기를 다루는 용도.
  양 플랫폼에서 빌드되는 건 확인했지만 그 시나리오가 아직 없다. 필요해지면 재검토.

---

## 관련 문서

- [`README.md`](README.md) — 이 디렉토리(도구 안내서)의 인덱스
- [`browser-tooling.md`](browser-tooling.md) — 데스크톱 쪽 웹 검증 도구
- [`local-https-proxy.md`](local-https-proxy.md) — 실기기에 공인 HTTPS URL 주기
