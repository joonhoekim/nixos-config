# 웹 소스 툴체인

Next/Nest 소스를 **읽고, 고치고, 고친 것을 검증하는** 도구 모음. 선언은
`modules/shared/packages.nix`의 "Editor / LSP toolchain" 절에 있다.

---

## 왜 전역에 두는가

언어 서버와 포매터는 성격이 갈린다.

**언어 서버는 전역이 맞다.** 에디터 하나가 붙잡는 프로세스고, 프로젝트마다
버전이 달라야 할 이유가 없다. 전역에 없으면 LazyVim의 Mason 같은 것이
`~/.local/share`에 알아서 깔기 시작하는데, 그건 nix가 모르는 상태다.

**포매터·린터는 프로젝트가 정본이다.** `.prettierrc`와 eslint 설정, 그리고
`package.json`에 핀된 버전이 최종 권한이다. 여기 있는 것들은 두 자리를 메운다 —
설정을 안 들고 다니는 저장소, 그리고 저장소를 아직 설치하지 않은 상태에서의
일회성 검사.

**`biome`이 그 두 번째 자리의 답이다.** 설정 파일 없이도 린트와 포맷을 둘 다
하고, 바이너리 하나로 끝나고, 종료코드로 판정된다. `pnpm install`을 돌리기 전에도
방금 고친 파일이 문법적으로 성립하는지 확인할 수 있다는 뜻이라, **에이전트가
자기 편집을 검증하는 기본 수단**이 된다.

---

## 무엇이 있나

| 도구 | 한 줄 | 대표 용도 |
|---|---|---|
| `vtsls` | TypeScript/TSX LSP | 타입·정의이동·리네임 (VSCode와 같은 방식으로 tsserver 구동) |
| `vscode-langservers-extracted` | html/css/json/eslint LSP 묶음 | JSON 스키마 검증, CSS 완성 |
| `tailwindcss-language-server` | Tailwind LSP | 클래스명 완성·호버 |
| `yaml-language-server` | 스키마 검증이 붙은 YAML LSP | k8s 매니페스트, compose, Actions |
| `dockerfile-language-server-nodejs` | Dockerfile LSP | |
| `biome` | 린터+포매터 한 바이너리, 설정 선택 | 설정 없는 저장소, 편집 후 자가검증 |
| `prettierd` | prettier 상주 데몬 | 저장 시 포맷 (node 기동시간 제거) |
| `eslint_d` | eslint 상주 데몬 | 저장 시 린트 |
| `ast-grep` | 구문 트리 기반 검색·치환 | 코드모드, 패턴 조사 |
| `typos` | 소스 인지 맞춤법 검사 | 식별자·주석의 오타 |
| `tree-sitter` | 파서 생성기 CLI | 문법 디버깅 |

린트 대상이 코드가 아닌 파일들 — `yamllint`/`yamlfmt`/`markdownlint-cli2` — 도
같은 절에 있다.

---

## `ast-grep` — 이 목록에서 가장 손이 많이 갈 물건

`ripgrep`은 **텍스트**를 본다. `ast-grep`은 **구문 트리**를 본다. 차이가 실제로
드러나는 자리는 이렇다.

```sh
# rg: 주석·문자열·다른 줄에 걸친 호출을 다 놓치거나 다 잡는다
rg 'useEffect\('

# ast-grep: 진짜 호출만. 인자 형태까지 조건에 넣을 수 있다
ast-grep run -p 'useEffect($$$A)' -l tsx
```

**패턴은 그 언어의 소스 코드로 쓴다.** 별도 질의 언어가 없다. `$A`는 노드 하나,
`$$$A`는 노드 여러 개.

> 명령은 `ast-grep`이다. 업스트림이 주는 `sg` 별칭은 nixpkgs가 뺐다 — 리눅스에서
> `sg`는 shadow의 setgid 명령이라 이름이 부딪힌다.

### 치환 (코드모드)

```sh
# 미리보기 — 바꾸지 않고 diff만 보여준다
ast-grep run -p 'console.log($$$A)' -r 'logger.debug($$$A)' -l ts

# 실제로 적용
ast-grep run -p 'console.log($$$A)' -r 'logger.debug($$$A)' -l ts -U
```

### 기계가 읽는 출력

```sh
ast-grep run -p 'catch ($E) { }' -l ts --json=compact
```

`--json`이 붙으면 파일·행·열·매치 텍스트가 구조로 나온다. 사람용 출력을 다시
파싱할 필요가 없어서, 스크립트나 에이전트가 결과를 바로 소비할 수 있다.

### 규칙 파일

한 번 쓰고 버릴 패턴이 아니라 저장소에 남길 규칙이면 YAML로 쓴다.

```yaml
# sgconfig.yml 과 rules/no-any.yml
id: no-explicit-any
language: typescript
rule:
  pattern: 'as any'
severity: warning
message: '`as any` 대신 좁은 타입을 쓸 것'
```

```sh
ast-grep scan            # 저장소의 모든 규칙을 돌린다
```

같은 자리를 겨냥하는 `semgrep`(선언은 보안 절, 문서는
[`security-hygiene.md`](security-hygiene.md))과의 갈림길: **한 줄짜리 즉석
패턴과 코드모드는 `ast-grep`**, 데이터 흐름을 따라가야 하거나 이미 있는
룰셋(`p/typescript`, `p/owasp-top-ten`)을 쓰고 싶으면 **`semgrep`**.

---

## 레시피

### 프로젝트 설치 없이 방금 고친 파일 검증

```sh
biome check src/app/page.tsx          # 린트 + 포맷 검사, 종료코드로 판정
biome check --write src/              # 고칠 수 있는 것은 고친다
biome format --write src/lib/foo.ts
```

`node_modules`가 없어도 돌아간다. 프로젝트가 `biome.json`을 들고 있으면 그것을
따르고, 없으면 내장 기본값으로 돈다.

### 타입 검사는 여전히 프로젝트 것으로

`biome`은 타입을 보지 않는다 (파서만 돈다). 타입 오류는 프로젝트의 tsc가 정본이다.

```sh
pnpm exec tsc --noEmit
```

`vtsls`가 에디터 안에서 같은 정보를 주지만, 스크립트로 판정할 때는 위쪽을 쓴다.

### 프로젝트 규칙을 따라 포맷

```sh
prettierd src/app/page.tsx            # 결과를 stdout 으로
eslint_d --fix src/                   # 프로젝트 eslint 설정을 그대로 읽는다
```

두 데몬 모두 첫 호출에서 뜨고 이후 상주한다. 설정을 바꿨는데 반영이 안 되면
데몬을 재시작한다.

```sh
prettierd restart
eslint_d restart
```

### 오타 검사

```sh
typos                       # 저장소 전체
typos --write-changes       # 확실한 것만 고친다
```

영어 단어의 흔한 철자 뒤집힘은 잡고 `pnpm` 같은 식별자는 안 잡는다.

**인라인 무시 주석을 지원하지 않는다.** `typos:ignore` 류를 달아도 무시되므로,
예외는 전부 저장소 루트의 `_typos.toml`로 만든다. 이 저장소에도 하나 있다 —
도구 이름(`wrk`), 커널 용어(`cros_ec_*`, PCI `BARs`), GLSL 변수(`ba`)가 들어 있다.

### YAML·Markdown

```sh
yamllint .github/workflows/
yamlfmt -lint k8s/          # -lint 는 고치지 않고 판정만
markdownlint-cli2 'docs/**/*.md'
```

---

## 에디터에 붙이기

이 저장소는 에디터 설정을 선언하지 않는다 (`helix`는 기본 설정으로 대부분의 LSP를
자동 인식한다). 직접 붙일 때 쓰는 실행 파일 이름은 이렇다.

| 언어 | 명령 |
|---|---|
| TypeScript/TSX | `vtsls --stdio` |
| HTML | `vscode-html-language-server --stdio` |
| CSS | `vscode-css-language-server --stdio` |
| JSON | `vscode-json-language-server --stdio` |
| ESLint | `vscode-eslint-language-server --stdio` |
| Tailwind | `tailwindcss-language-server --stdio` |
| YAML | `yaml-language-server --stdio` |
| Dockerfile | `docker-langserver --stdio` |

---

## 함정

**`vtsls`는 프로젝트의 typescript를 쓴다.** 저장소에 `node_modules/typescript`가
있으면 그쪽 버전으로 돈다. 즉 `pnpm install` 전에는 타입 정보가 반쪽이다 — 이건
고장이 아니라 정상이고, 그래서 설치 전 검증은 `biome` 몫이다.

**`biome`과 프로젝트 prettier가 같은 파일을 다르게 포맷한다.** 둘 다 저장 시
돌게 해 두면 파일이 왔다 갔다 한다. 프로젝트에 prettier 설정이 있으면 `biome
format`은 그 저장소에서 쓰지 않는다 — `biome check --linter-only`로 린트만 쓰는
길이 있다.

**`ast-grep`의 `-l`은 생략하면 확장자로 추론한다.** 다만 `.ts`와 `.tsx`는 문법이
달라서, tsx 파일에 `-l ts`를 주면 JSX가 들어간 지점에서 조용히 매치가 안 된다.
매치가 0개면 언어부터 의심할 것.

---

## 안 넣은 것과 이유

- **`typescript` / `tsc`** — 언어 런타임과 같은 규칙이다. 프로젝트가 핀한
  버전으로 도는 것이 유일하게 옳고, 전역 `tsc`는 그 핀과 어긋난 결과를 낸다.
  `pnpm exec tsc`를 쓴다.
- **`nodePackages.*` 계열 (eslint, prettier 본체)** — 위와 같은 이유. 데몬
  래퍼(`prettierd`/`eslint_d`)만 전역에 두고, 실제 엔진은 프로젝트 것을 찾아 쓴다.
- **`oxlint` / `quick-lint-js`** — `biome`과 자리가 겹친다. 같은 일을 하는 도구가
  둘이면 어느 쪽 결과가 정본인지가 매번 애매해진다.

---

## 관련 문서

- [`README.md`](README.md) — 이 디렉토리(도구 안내서)의 인덱스
- [`security-hygiene.md`](security-hygiene.md) — `semgrep`·`trivy` 등 정적 검사
- [`../02-this-repo.md`](../02-this-repo.md) — 선언이 어느 파일로 흘러가는지
