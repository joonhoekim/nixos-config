# 보안 위생 도구

시크릿과 의존성 취약점을 **사고가 나기 전에** 잡는 도구 모음. 선언은
`modules/shared/packages.nix`의 "Encryption and security tools" 절에 있다.

---

## 왜 따로 필요한가

템플릿 레포(ts-fullstack-project-template)가 프로젝트마다 복제되는 구조라서,
시크릿 실수 커밋이나 취약한 의존성이 **복제된 모든 프로젝트로 퍼진다**. 개별
프로젝트의 npm 스크립트에 맡기는 대신 nix로 깔아 두면, 복제본마다 설정 없이
같은 게이트를 공짜로 얻는다.

세 도구의 역할 분담:

| 도구 | 지키는 것 | 시점 |
|---|---|---|
| `sops` (+ 기존 `age`) | 시크릿을 **애초에 평문으로 두지 않기** | 평소 |
| `gitleaks` | 그래도 실수로 커밋된 시크릿 | pre-push / CI |
| `osv-scanner` | 의존성에 알려진 취약점 | CI / 수시 |

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

## 안 넣은 것과 이유

- **`oasdiff`** — OpenAPI 스펙 두 개를 비교해 breaking change만 추출하는 도구.
  넣고 싶었지만 **nixpkgs에 없다** (2026-08-17 확인 — 레포 핀·레지스트리 양쪽).
  용도가 CI 게이트라 GitHub Action(`oasdiff-action`)이나
  `go install github.com/oasdiff/oasdiff@latest`로 쓰는 쪽이 현실적이다.
  nixpkgs에 등록되면 재검토.
- **`trivy` / `grype`** — 컨테이너 이미지 스캔까지 가면 후보지만, 지금 빈틈은
  락파일 수준이고 osv-scanner로 충분하다. 이미지 배포 파이프라인이 생기면 재검토.

---

## 관련 문서

- [`README.md`](README.md) — 이 디렉토리(도구 안내서)의 인덱스
- [`../03-operating-on-macos.md`](../03-operating-on-macos.md) — 패키지를 더한 뒤의 반영 절차
