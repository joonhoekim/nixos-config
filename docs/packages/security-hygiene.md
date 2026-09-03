# 보안 위생 도구

시크릿과 의존성 취약점을 **사고가 나기 전에** 잡는 도구 모음. 선언은
`modules/shared/packages.nix`의 "Encryption and security tools" 절에 있다.

---

## 왜 따로 필요한가

템플릿 레포(ts-fullstack-project-template)가 프로젝트마다 복제되는 구조라서,
시크릿 실수 커밋이나 취약한 의존성이 **복제된 모든 프로젝트로 퍼진다**. 개별
프로젝트의 npm 스크립트에 맡기는 대신 nix로 깔아 두면, 복제본마다 설정 없이
같은 게이트를 공짜로 얻는다.

역할 분담:

| 도구 | 지키는 것 | 시점 |
|---|---|---|
| `sops` (+ 기존 `age`) | 시크릿을 **애초에 평문으로 두지 않기** | 평소 |
| `gitleaks` | 그래도 실수로 커밋된 시크릿 | pre-push / CI |
| `lefthook` | 위 두 가지를 **실제로 돌게 하는 것** | 커밋·푸시 시점 |
| `osv-scanner` | 의존성에 알려진 취약점 | CI / 수시 |
| `trivy` | 컨테이너 이미지·IaC 설정·시크릿까지 넓게 | 이미지 빌드 후 / CI |
| `semgrep` | 소스 코드 자체의 취약 패턴 | CI / 규칙을 쓸 때 |
| `hadolint` | Dockerfile이 만드는 취약한 이미지 | 커밋 시점 |

`gitleaks`와 `trivy`가 겹치는 부분(시크릿 검출)이 있지만 겨냥하는 자리가 다르다 —
`gitleaks`는 **git 히스토리**, `trivy`는 **빌드된 산출물**이다. 커밋에는 없는데
이미지 레이어에는 들어간 `.env`는 `trivy`만 잡는다.

---

## sops + age — 시크릿을 레포에 안전하게 두기

`age`는 원래부터 세트에 있었는데 짝이 없었다. sops가 그 반쪽이다 — 환경별
`.env`를 age로 암호화해 레포에 커밋하는 표준 조합.

```sh
# 키가 없으면 한 번만
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt   # public key 가 출력된다

# 레포 루트에 규칙 선언 (.sops.yaml)
cat > .sops.yaml <<'EOF'
creation_rules:
  - path_regex: \.env\.(staging|prod)$
    age: age1...   # age-keygen 이 출력한 public key
EOF

sops -e .env.prod > .env.prod.enc    # 암호화해서 커밋하는 쪽
sops -d .env.prod.enc                # 복호화 (키 있는 사람만)
sops .env.prod.enc                   # 에디터로 직접 수정 (평문을 디스크에 안 남김)
```

dotenv 형식은 `--input-type dotenv --output-type dotenv`를 붙이면 키 이름은
평문으로 남고 값만 암호화되어 diff 리뷰가 가능하다.

---

## gitleaks — 커밋된 시크릿 잡기

```sh
gitleaks detect --source .           # 히스토리 전체 스캔
gitleaks protect --staged            # 스테이징된 변경만 (pre-commit 용)
```

훅에 물리는 게 본래 용도다. 템플릿 레포라면 husky pre-push에 한 줄:

```sh
gitleaks protect --staged --redact   # --redact: 터미널에 시크릿 원문을 안 띄움
```

이미 커밋된 과거 히스토리에서 오탐이 나오면 `.gitleaksignore`에 fingerprint를
추가한다 (스캔 결과에 fingerprint가 같이 출력된다).

---

## osv-scanner — 의존성 취약점 스캔

`pnpm audit`보다 DB 범위가 넓다(OSV.dev — npm advisory 포함 상위집합).
better-auth advisory를 수동 리서치로 확인했던 일이 이걸로 자동화된다.

```sh
osv-scanner scan --lockfile pnpm-lock.yaml   # 락파일 하나
osv-scanner scan -r .                        # 레포 재귀 (여러 락파일)
```

CI 게이트로 쓸 때는 종료코드로 분기하면 된다 — 취약점 발견 시 비영이다.
오탐/보류는 `osv-scanner.toml`의 `[[IgnoredVulns]]`로 관리한다.

---

## trivy — 락파일 바깥까지

`osv-scanner`가 락파일에 적힌 의존성을 본다면, `trivy`는 **최종 산출물**을 본다.
베이스 이미지의 OS 패키지, 이미지 레이어에 딸려 들어간 시크릿, IaC 파일의
설정 실수 — 전부 락파일에는 안 나타나는 것들이다.

```sh
trivy image myapp:latest                  # 이미지 (OS 패키지 + 앱 의존성)
trivy fs .                                # 디렉토리 — 락파일·시크릿·미스컨피그
trivy config .                            # IaC 만 (Dockerfile·k8s·terraform)
trivy repo https://github.com/…           # 클론 없이 원격 레포
```

게이트로 쓸 때:

```sh
trivy image --severity HIGH,CRITICAL --exit-code 1 --ignore-unfixed myapp:latest
```

`--ignore-unfixed`가 실무에서 중요하다. 이게 없으면 **고칠 방법이 없는**
취약점까지 빌드를 막아서, 결국 게이트 전체를 꺼 버리게 된다.

오탐 관리는 `.trivyignore`(CVE ID 한 줄씩)로 한다.

---

## semgrep — 소스 코드의 패턴

의존성이 아니라 **우리가 쓴 코드**를 본다. 규칙이 YAML이라 프로젝트 고유의
금지 패턴을 직접 쓸 수 있다.

```sh
semgrep --config p/typescript .           # 커뮤니티 TS 룰셋
semgrep --config p/owasp-top-ten .
semgrep --config ./rules/ .               # 직접 쓴 규칙
semgrep --config auto --json -o out.json  # 기계가 읽는 출력
```

직접 쓰는 규칙의 모양:

```yaml
rules:
  - id: no-raw-query-interpolation
    languages: [typescript]
    severity: ERROR
    message: 템플릿 리터럴로 SQL을 만들지 말 것 — 파라미터 바인딩을 쓴다
    pattern: $REPO.query(`...${$X}...`)
```

기성 룰셋(`p/typescript`, `p/owasp-top-ten`)과 **데이터 흐름 추적(taint)** 이
이 도구의 자리다.

---

## hadolint — Dockerfile

```sh
hadolint Dockerfile
hadolint --failure-threshold error Dockerfile    # 경고는 통과시킬 때
```

`RUN` 안의 셸까지 shellcheck로 본다. 보안 관점에서 값어치가 큰 건
`USER`를 지정하지 않아 root로 도는 이미지, 핀 없는 `apt-get install`,
`ADD`로 원격 URL을 당겨오는 패턴 같은 것들이다.

무시는 파일 안에 주석으로 단다: `# hadolint ignore=DL3008`.

---

## lefthook — 위의 것들을 실제로 돌게 하기

여기 있는 도구는 **돌지 않으면 아무 값어치가 없다.** 훅 관리자가 그 자리를
메운다. husky와 달리 설정이 YAML 하나고, node 의존성이 아니라 단일 바이너리라
템플릿 레포가 어떤 언어든 같은 방식으로 쓴다.

```yaml
# lefthook.yml
pre-commit:
  parallel: true
  commands:
    secrets:
      run: gitleaks protect --staged --redact
    format:
      glob: '*.{ts,tsx}'
      run: biome check --write {staged_files}
      stage_fixed: true
    dockerfile:
      glob: 'Dockerfile*'
      run: hadolint {staged_files}

pre-push:
  commands:
    deps:
      run: osv-scanner scan -r .
```

```sh
lefthook install          # .git/hooks 에 심는다 (레포마다 한 번)
lefthook run pre-commit   # 커밋 없이 수동 실행
```

`{staged_files}`가 핵심이다. 저장소 전체가 아니라 방금 건드린 파일만 검사해서
훅이 느려지지 않는다 — 느린 훅은 결국 `--no-verify`로 우회당한다.

---

## 안 넣은 것과 이유

- **`oasdiff`** — OpenAPI 스펙 두 개를 비교해 breaking change만 추출하는 도구.
  넣고 싶었지만 **nixpkgs에 없다** (2026-08-17 확인 — 레포 핀·레지스트리 양쪽).
  용도가 CI 게이트라 GitHub Action(`oasdiff-action`)이나
  `go install github.com/oasdiff/oasdiff@latest`로 쓰는 쪽이 현실적이다.
  nixpkgs에 등록되면 재검토.
- **`grype`** — `trivy`와 자리가 그대로 겹친다. 이미지 스캐너가 둘이면 결과가
  갈렸을 때 어느 쪽이 정본인지가 매번 문제가 된다.
- **`husky`** — `lefthook`과 같은 자리. npm 의존성이라 프로젝트마다 설치가
  필요하고, 훅 하나가 셸 스크립트 파일 하나라서 병렬 실행과 대상 파일 필터를
  직접 짜야 한다.

---

## 관련 문서

- [`README.md`](README.md) — 이 디렉토리(도구 안내서)의 인덱스
- [`../03-operating-on-macos.md`](../03-operating-on-macos.md) — 패키지를 더한 뒤의 반영 절차
