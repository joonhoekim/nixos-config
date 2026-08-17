# 브라우저 확인 도구

로컬 웹 앱을 **눈으로 확인해야 할 때** 쓰는 도구 모음. 선언은
`modules/shared/packages.nix`의 "Browser automation / web verification" 절,
환경변수는 `modules/shared/programs/zsh.nix`에 있다.

---

## 왜 따로 필요한가

브라우저를 자동으로 다루는 경로는 두 가지고, 성격이 다르다.

**Claude-in-Chrome 확장** — 지금 열려 있는 **살아 있는 Chrome**에 붙는다. 로그인
세션과 쿠키를 그대로 쓰므로 인증이 필요한 페이지를 볼 때 유일한 선택지다. 대신
확장이 연결돼 있지 않으면 아무것도 못 하고, 그 사실이 **작업 중간에야** 드러난다.

**여기 있는 도구들** — 헤드리스 브라우저를 직접 띄운다. 확장도 로그인 세션도
필요 없고, 스크립트로 돌릴 수 있고, CI에서도 같은 결과가 나온다. 로컬 개발 서버를
확인하는 일상적인 용도는 대부분 이쪽이 맞다.

정리하면 **인증된 실제 세션이 필요하면 확장, 그 외에는 여기 도구들.**

---

## 무엇이 있나

| 도구 | 한 줄 | 대표 용도 |
|---|---|---|
| `playwright-mcp` | Claude Code에 브라우저 도구를 붙이는 MCP 서버 | 에이전트가 직접 클릭·스크린샷·콘솔 읽기 |
| `playwright` | 브라우저 자동화 CLI/라이브러리 | 스크립트, `codegen`으로 조작 녹화 |
| `playwright-driver.browsers` | nix가 고정한 Chromium·Firefox·WebKit | 런타임 브라우저 다운로드 제거 |
| `shot-scraper` | URL → PNG 한 줄 | 스크린샷, 페이지에서 값 뽑기 |
| `odiff` | 빠른 픽셀 비교 | 변경 전후·라이트/다크 대조 |
| `imagemagick` | 이미지 자르기·합치기·주석 | 테마 쌍을 나란히 붙이기 |
| `htmlq` | HTML에 CSS 선택자 (HTML판 jq) | 서버 렌더 결과 검사 |
| `lychee` | 실제로 요청을 보내는 링크 검사기 | 살아 있는 404 잡기 |
| `hurl` | HTTP 요청을 평문 파일로 쓰고 응답을 assert | API 계약 테스트, CI에서 그대로 |
| `mitmproxy` | HTTPS 복호화 프록시 | 앱이 실제로 뭘 보내는지 관찰·재전송 |
| `miniserve` | 정적 파일 서버 단일 바이너리 | `file://` 우회, CORS·SPA 폴백 |
| `websocat` | WebSocket판 curl | WS 엔드포인트 수동 확인 |
| `k6` | JS로 시나리오 쓰는 부하 테스트 | 성능 스모크 테스트 |
| `wrk` | 단순 HTTP 처리량 측정 | "몇 RPS 버티나"만 볼 때 |
| `html-tidy` | HTML 검증기 (`tidy`) | htmlq가 넘어가는 깨진 마크업 잡기 |

HTTP 클라이언트 `xh`(httpie 호환)는 같은 파일의 네트워킹 절에 이미 있다.

---

## Playwright MCP — 에이전트에게 브라우저를 주는 법

가장 자주 쓰게 될 물건이다. 등록은 한 번만 하면 된다.

```sh
# 이 프로젝트에서만 (권장 — 프로젝트 .mcp.json에 기록되어 팀과 공유된다)
claude mcp add --scope project playwright -- playwright-mcp --headless

# 모든 프로젝트에서
claude mcp add --scope user playwright -- playwright-mcp --headless

claude mcp list          # 등록 확인
```

MCP 설정은 Claude Code가 관리하는 **가변 상태**라 이 저장소에서 선언하지 않는다
(선언해 버리면 `claude mcp` 명령과 서로 덮어쓴다). 패키지만 nix가 깔아 주고,
등록은 위 명령으로 한다.

자주 쓰는 옵션:

| 옵션 | 뜻 |
|---|---|
| `--headless` | 창 없이 (기본은 창을 띄운다) |
| `--browser chrome` | 번들 Chromium 대신 설치된 Chrome 사용 |
| `--device "iPhone 15"` | 모바일 뷰포트 흉내 |
| `--save-trace` | 트레이스 저장 (`--output-dir`와 함께) |
| `--isolated` | 프로필을 남기지 않는 일회성 세션 |

> `.playwright-mcp/`는 MCP 서버가 스크린샷·트레이스를 떨구는 작업 디렉토리다.
> 쓰는 프로젝트라면 `.gitignore`에 넣어 둘 것.

---

## 브라우저는 어디서 오나

`zsh.nix`가 두 변수를 내보낸다.

```sh
export PLAYWRIGHT_BROWSERS_PATH="/nix/store/…-playwright-browsers"
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
```

이게 없으면 `npm i playwright`를 한 프로젝트마다 400MB짜리 브라우저를
`~/Library/Caches/ms-playwright`에 새로 받고, nix가 모르는 그 바이너리로 돌게 된다.
버전이 프로젝트마다 갈리는 것이 진짜 비용이다 — 재현이 안 되는 스크린샷은 없느니만
못하다.

⚠️ **버전 짝이 맞아야 한다.** npm 쪽 `playwright` 버전이 nix가 고정한 드라이버
버전과 다르면 "Executable doesn't exist" 에러가 난다. 그때는 프로젝트의
`playwright`를 맞추거나, 그 프로젝트에서만 `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD`를
풀고 자체 다운로드를 허용한다.

```sh
playwright --version                      # nix가 깐 쪽
node -e 'console.log(require("playwright/package.json").version)'   # 프로젝트 쪽
```

---

## 레시피

### 스크린샷 한 장

```sh
shot-scraper http://localhost:3000/docs/dev/cs/9.hash-contract -o out.png --wait 2000
```

### 라이트/다크 한 쌍을 나란히

`prefers-color-scheme`을 흉내내는 대신, 사이트가 실제로 쓰는 토글을 건드리는 편이
정확하다 (이 블로그는 `<html data-theme>`).

```sh
URL=http://localhost:3000/docs/dev/cs/26.collision-intuition
shot-scraper "$URL" -o light.png --wait 2000
shot-scraper "$URL" -o dark.png  --wait 2000 \
  --javascript "document.documentElement.dataset.theme='dark'"
magick montage light.png dark.png -tile 2x1 -geometry +8+8 pair.png
```

### 페이지에서 값 뽑기 (렌더 후)

`curl | grep`은 서버가 보낸 HTML만 본다. **클라이언트가 그린 것**을 보려면 이쪽.

```sh
shot-scraper javascript http://localhost:3000/docs/dev/cs/37.defect-taxonomy \
  "document.querySelectorAll('dt').length"
```

### 콘솔 에러 수집

```sh
shot-scraper javascript "$URL" "
  new Promise(r => setTimeout(() => r(window.__errs || []), 2000))
" --log-console
```

### 변경 전후 픽셀 비교

```sh
odiff before.png after.png diff.png --threshold 0.05
# 종료코드 0 = 동일, 21 = 다름 → 스크립트에서 분기 가능
```

### 서버 렌더 HTML 검사 (브라우저 없이)

```sh
curl -s "$URL" | htmlq --text 'h2'          # 헤딩만
curl -s "$URL" | htmlq 'iframe' --attribute srcdoc | head -c 400
```

### 링크 검사 (실제 요청)

빌드 타임 참조 검사와 다르다 — 외부 링크의 진짜 404를 잡는다.

```sh
lychee --base http://localhost:3000 --exclude-mail 'content/**/*.mdx'
lychee --max-concurrency 4 http://localhost:3000/docs/dev/cs/0.series
```

### API 응답 assert (hurl)

요청과 기대치를 한 파일에 쓰고 돌린다. 실패하면 비영 종료코드라 CI에 바로 물린다.

```sh
cat > smoke.hurl <<'EOF'
GET http://localhost:3000/api/health
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
EOF
hurl --test smoke.hurl
```

### 앱이 실제로 보내는 요청 보기 (mitmproxy)

브라우저 devtools 밖에서 — CLI 도구·백엔드가 뭘 보내는지 볼 때.

```sh
mitmproxy --listen-port 8080          # TUI. 웹 UI가 좋으면 mitmweb
curl -x http://localhost:8080 -k https://api.example.com/…   # 프록시를 태워 관찰
```

### WebSocket 엔드포인트 찔러보기

```sh
websocat ws://localhost:3000/ws       # 대화형 — 타이핑한 줄이 메시지로 나간다
echo '{"type":"ping"}' | websocat -n1 ws://localhost:3000/ws   # 한 발 쏘고 응답만
```

### 성능 스모크

```sh
wrk -t4 -c64 -d10s http://localhost:3000/          # 처리량 숫자 하나면 될 때
k6 run script.js                                    # 시나리오(로그인 → 조회 → …)가 필요할 때
```

### iframe 안에 있는 것 확인하기

`sandbox="allow-scripts"`만 준 iframe은 **부모에서 내용을 못 읽는다**
(`contentDocument`가 `no-access`). 이건 고장이 아니라 격리가 제대로 걸렸다는 증거다.
그래서 안을 보려면 두 가지 우회가 필요하다.

**보이게 만든 뒤 화면으로 찍는다.** 요소 스크린샷(`--selector iframe`)은 iframe 합성을
놓쳐 빈 이미지가 나오는 경우가 있으므로, 스크롤해서 뷰포트에 넣고 페이지를 찍는 편이
확실하다.

```sh
shot-scraper "$URL" -o out.png --width 1400 --height 900 --wait 6000 \
  --javascript "document.querySelector('iframe').scrollIntoView({block:'center'})"
```

**콘텐츠 높이를 재려면 srcdoc을 따로 띄운다.** iframe에 줄 `height`가 맞는지 보려면
같은 문서를 같은 폭으로 단독 렌더해서 전체 페이지 높이를 잰다.

```sh
# srcdoc을 파일로 뽑아 두고, 정적 서버로 띄운 뒤
miniserve -p 8899 . &
shot-scraper http://localhost:8899/sim.html -o h.png --width 846   # --height 생략 = 전체 페이지
magick identify -format '%h' h.png                                  # = 그 폭에서의 콘텐츠 높이
```

---

## 함정

**`file://`은 안 먹는다.** `shot-scraper`가 스킴을 잘못 붙여
`http://file///…`로 요청한다(`ERR_NAME_NOT_RESOLVED`). 로컬 HTML은 위처럼
`miniserve`로 띄워서 볼 것 (CORS가 필요하면 `--header` 플래그, SPA면 `--spa`).

**`shot-scraper javascript`에는 `--width`가 없다.** 뷰포트 폭은 항상 기본값(1280)이라
반응형 분기가 있는 페이지에서는 실제와 다른 값을 잰다. 폭이 중요하면 `shot` 쪽
(`--width`)을 쓰고 이미지 크기로 역산한다.

**스크롤 컨테이너가 `window`가 아닐 수 있다.** 사이드바가 따로 스크롤되는 문서 사이트는
`<main>`이 스크롤 컨테이너라 `window.scrollTo`가 아무 일도 하지 않는다. 요소에
`scrollIntoView()`를 부르는 쪽이 컨테이너를 알아서 찾아준다.

---

## 안 넣은 것과 이유

기록해 두지 않으면 "왜 없지?"를 다시 조사하게 된다.

- **`chromium`** — nixpkgs가 `aarch64-darwin`을 지원 대상에서 뺐다
  (`meta.platforms`에 darwin이 없다). 브라우저는 `playwright-driver.browsers`나
  설치된 `google-chrome` cask로 충분하다.
- **`lighthouse`** — nixpkgs에서 `meta.broken = true`다 (2026-08-07 재확인, 여전함).
  성능·접근성 감사가 필요하면 `npx lighthouse`를 쓰거나, 고쳐졌는지 다시 확인할 것.
- **`pa11y`** — nixpkgs에 없다. 접근성 검사는 `npx @axe-core/cli` 또는
  Playwright에 `@axe-core/playwright`를 붙이는 쪽이 현실적이다.
- **`pup` / `monolith`** — 각각 `htmlq`와 역할이 겹치거나(HTML 질의),
  용도가 다르다(페이지 통째 아카이빙).

---

## 관련 문서

- [`README.md`](README.md) — 이 디렉토리(도구 안내서)의 인덱스
- [`../03-operating-on-macos.md`](../03-operating-on-macos.md) — 패키지를 더한 뒤의 반영 절차
- [`../02-this-repo.md`](../02-this-repo.md) — 선언이 어느 파일로 흘러가는지
