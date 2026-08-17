# 패키지 안내서

`modules/*/packages.nix`의 선언과 짝을 이루는 **도구 안내서** 모음.
선언만 해 두고 문서를 안 남기면 깔려 있다는 사실 자체를 잊어버리기 때문에,
"왜 넣었는지 + 어떻게 쓰는지 + 무엇을 일부러 안 넣었는지"를 주제별로 적는다.

문서 단위는 패키지가 아니라 **시나리오**다 — 한 문서 안의 도구들은 같은 상황에서
함께 꺼내 쓰게 된다.

| 문서 | 다루는 상황 |
|---|---|
| [`browser-tooling.md`](browser-tooling.md) | 로컬 웹 앱을 눈으로/스크립트로 확인 (스크린샷·픽셀 비교·HTTP 검사) |
| [`local-https-proxy.md`](local-https-proxy.md) | prod의 도메인·쿠키·HTTPS 조건을 로컬에서 재현 (caddy·mkcert·cloudflared) |
| [`security-hygiene.md`](security-hygiene.md) | 시크릿과 의존성 취약점 게이트 (sops·gitleaks·osv-scanner) |
| [`mobile.md`](mobile.md) | 실기기(폰)에서 보고 조작하기, iOS/Android 툴체인 (adb·scrcpy·…) |
| [`everyday-tools.md`](everyday-tools.md) | 개발 무관 일상 편의 — 다운로드·이미지·문서·전송·한국어 zip (yt-dlp 짝들) |

## 단독 문서가 없는 것들

한 줄이면 충분한 도구는 `packages.nix`의 주석이 정본이다. 예: `iredis`는
"pgcli의 redis 대응물" 이상 설명할 게 없다. 주석 한 줄로 부족해지는 순간
(레시피·함정이 생기는 순간) 여기로 승격한다.

## 관련 문서

- [`../03-operating-on-macos.md`](../03-operating-on-macos.md) — 패키지를 더한 뒤의 반영 절차
- [`../02-this-repo.md`](../02-this-repo.md) — 선언이 어느 파일로 흘러가는지
