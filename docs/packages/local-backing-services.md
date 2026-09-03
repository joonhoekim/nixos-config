# 로컬 의존 서비스

백엔드가 기대하는 **주변 인프라를 컨테이너 없이 세우는** 도구 모음, 그리고 세워
놓은 것을 들여다보는 도구들. 선언은 `modules/shared/packages.nix`의
"Local backing services" 절과 "Infra / DB / network" 절에 있다.

---

## 왜 필요한가

기능 하나를 확인하려고 compose 파일 전체를 띄우는 비용이 문제다. 파일 업로드
한 줄을 고쳤는데 S3가 필요하고, 회원가입 흐름을 보려는데 메일 발송이 필요하다.
컨테이너를 띄우는 순간 **네트워크·볼륨·기동 순서**가 얽히고, 그 얽힘이 정작
확인하려던 것과 아무 상관이 없다.

여기 있는 것들은 전부 **단일 바이너리에 디렉토리 하나**다. 셸에서 뜨고 셸과 함께
죽는다. 상태가 남지 않으니 다시 처음부터 하기 쉽고, 무엇보다 **AI 에이전트가
붙잡고 확인하기 좋다** — 백그라운드 프로세스 하나와 포트 하나면 끝난다.

반대로, 설정이 프로젝트마다 크게 갈리는 것(메시지 브로커, DB 자체)은 여기에
없다. 그건 compose 파일이 정본인 편이 낫다.

---

## 무엇이 있나

| 도구 | 서는 자리 | 포트(기본) |
|---|---|---|
| `mailpit` | SMTP 수신함 + 웹 UI | 1025(SMTP) / 8025(UI) |
| `seaweedfs` | S3 호환 객체 저장소 (`weed`) | 8333(S3) |
| `minio-client` | S3 클라이언트 (`mc`) | — |
| `process-compose` | 프로세스 여러 개를 compose 문법으로 | 8080(UI) |
| `pg_activity` | 살아 있는 postgres 관측 | — |
| `sqlfluff` | SQL 린터·포매터 | — |

---

## mailpit — 메일을 실제로 안 보내면서 확인하기

가입 확인·비밀번호 재설정처럼 **메일이 흐름의 일부인 기능**은 발송이 안 되면
확인 자체가 막힌다. mailpit은 SMTP를 받아서 아무 데도 보내지 않고 웹 UI와 API에
쌓아 둔다.

```sh
mailpit                       # SMTP :1025, UI http://localhost:8025
```

앱 설정은 인증 없는 평문 SMTP로 맞춘다.

```
SMTP_HOST=localhost
SMTP_PORT=1025
SMTP_SECURE=false
```

UI를 안 열고 확인하려면 REST API가 있다 — 스크립트와 에이전트가 쓰는 길이다.

```sh
xh :8025/api/v1/messages                        # 받은 메일 목록
xh :8025/api/v1/message/latest                  # 가장 최근 한 통 (본문 포함)
xh :8025/api/v1/message/latest | jq -r '.Text'  # 본문만
xh DELETE :8025/api/v1/messages                 # 비우기 (테스트 사이에)
```

**메일 본문에서 토큰 뽑기** — 가입 확인 링크를 따라가는 E2E의 실제 모양이다.

```sh
xh :8025/api/v1/message/latest \
  | jq -r '.Text' \
  | rg -o 'https?://\S+/verify\?token=\S+'
```

---

## seaweedfs — 로컬 S3

```sh
weed server -dir=/tmp/s3 -s3 -s3.port=8333
```

설정 파일이 없다. 이게 minio 대신 이걸 쓰는 이유다 (아래 "왜 minio가 아닌가").

`mc`로 붙인다.

```sh
mc alias set local http://localhost:8333 any any   # 기본 설정은 인증을 안 건다
mc mb local/uploads
mc cp ./photo.png local/uploads/
mc ls local/uploads
mc cat local/uploads/photo.png > out.png
mc rm --recursive --force local/uploads
```

앱 SDK 쪽 설정에서 중요한 건 두 가지다.

```
S3_ENDPOINT=http://localhost:8333
S3_FORCE_PATH_STYLE=true      # 이것 없이는 bucket.localhost 로 붙으려 한다
```

**`forcePathStyle`을 빠뜨리는 것이 로컬 S3에서 가장 흔한 실패다.** AWS SDK v3는
기본이 virtual-hosted 스타일이라 `http://uploads.localhost:8333`으로 요청을 보내고,
그 호스트는 존재하지 않는다.

같은 `mc`가 진짜 AWS S3에도 붙으므로, 로컬과 운영을 같은 명령으로 다룰 수 있다.

```sh
mc alias set prod https://s3.ap-northeast-2.amazonaws.com "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY"
mc ls prod/my-bucket
```

### 왜 minio가 아닌가

업스트림이 minio를 버렸고, nixpkgs가 미수정 CVE 여섯 건(무인증 객체 쓰기 포함)을
이유로 insecure 표시를 달았다. 설치하려면 `permittedInsecurePackages`를 시스템
전체에 열어야 하는데, 로컬 스텁 하나 때문에 치를 값이 아니다.

nixpkgs가 지목한 이주처는 Garage와 SeaweedFS 둘이다. **`weed server -s3`가 설정
파일 없이 한 줄로 뜨는 것**이 SeaweedFS를 고른 이유다. Garage는 첫 PUT 전에
TOML 설정과 layout assign 단계를 요구한다 — 운영과 같은 모양(클러스터 레이아웃,
복제)이 필요할 때는 그쪽이 맞고, 그때 `garage`를 추가하면 된다.

---

## process-compose — 여러 프로세스를 한 번에

`next dev` + `nest start --watch` + 워커 + 위의 스텁들을 각각 다른 터미널에
띄우는 대신 하나로 묶는다. docker-compose 문법인데 컨테이너가 아니라 **그냥
프로세스**를 돌린다.

```yaml
# process-compose.yml
processes:
  mailpit:
    command: mailpit
    readiness_probe:
      http_get: { host: localhost, port: 8025, path: / }

  s3:
    command: weed server -dir=.data/s3 -s3 -s3.port=8333

  api:
    command: pnpm --filter api start:dev
    depends_on:
      mailpit: { condition: process_healthy }

  web:
    command: pnpm --filter web dev
    depends_on:
      api: { condition: process_started }
```

```sh
process-compose up                  # TUI
process-compose up -t=false         # TUI 없이 — 스크립트·CI·에이전트용
process-compose up -t=false -D      # 백그라운드 (데몬)
process-compose down
process-compose process logs api    # 프로세스 하나의 로그만
```

**`-t=false`가 에이전트에게 중요하다.** 기본 TUI는 터미널을 붙잡아서 프로그램이
읽을 수 있는 출력을 안 준다. 끄면 각 프로세스의 stdout이 접두어와 함께 그냥
흘러나온다.

`depends_on` + `readiness_probe`는 compose와 같은 의미다 — API가 뜨기 전에 웹이
먼저 요청을 보내는 경합을 없앤다.

---

## postgres를 들여다보기

CLI는 이미 셋 있다 — `psql`(postgresql 패키지), 자동완성이 붙은 `pgcli`,
TUI인 `lazysql`. 셋 다 **질의를 쓰는** 도구다. 아래 둘은 다른 자리를 본다.

### pg_activity — 지금 무슨 일이 벌어지고 있나

```sh
pg_activity -U postgres -h localhost -d mydb
```

`pg_stat_activity`를 실시간 TUI로 보여준다. `htop`의 postgres판이다.

값어치가 나오는 자리는 **느린 요청의 원인을 가를 때**다. 애플리케이션 로그는
"이 요청이 3초 걸렸다"까지만 말한다. 그게 무거운 질의 때문인지, 다른 트랜잭션이
잡은 락을 기다린 것인지는 여기서만 보인다 — 대기 중인 세션에 락 정보가 같이
뜬다.

`Ctrl-K`로 세션을 끊을 수 있으니, 개발 중에 붙잡힌 트랜잭션을 정리할 때도 쓴다.

### sqlfluff — 손으로 쓴 SQL 검사

ORM이 만드는 SQL은 대상이 아니다. 마이그레이션 파일이나 raw 질의처럼 **사람이
쓴 SQL**이 DB에 닿기 전에 검사한다.

```sh
sqlfluff lint --dialect postgres migrations/
sqlfluff fix  --dialect postgres migrations/0003_add_index.sql
sqlfluff format --dialect postgres query.sql
```

`--dialect postgres`를 매번 치기 싫으면 `.sqlfluff`에 적는다.

```ini
[sqlfluff]
dialect = postgres
templater = raw
exclude_rules = LT05
```

**`templater`가 함정이다.** 기본값이 jinja라, `${...}`나 `?` 같은 바인딩
플레이스홀더가 든 파일에서 템플릿 오류를 낸다. 순수 SQL 파일만 볼 거라면
`templater = raw`로 둔다.

---

## 함정

**포트가 이미 물려 있다.** mailpit의 8025, seaweedfs의 8333, process-compose의
8080은 흔한 번호다. 뜨자마자 죽으면 여기부터 본다.

```sh
lsof -i :8025
```

**상태 디렉토리를 지정하지 않으면 현재 디렉토리에 쌓인다.** `weed`는 `-dir`을
반드시 주고, 프로젝트 안이라면 `.gitignore`에 넣는다.

**`mc`의 alias는 `~/.mc/`에 남는다.** 이 저장소가 선언하지 않는 가변 상태다.
새 머신에서는 `mc alias set`부터 다시 해야 한다.

---

## 안 넣은 것과 이유

- **`minio`** — 위 "왜 minio가 아닌가" 참조. 업스트림 방기 + insecure 표시.
- **메시지 브로커 서버 (kafka·rabbitmq·nats-server)** — 설정이 프로젝트마다
  갈려서 compose 파일이 정본인 편이 낫다. **클라이언트**는
  [`backend-protocols.md`](backend-protocols.md)에 있다.
- **`postgresql` 서버 / `redis` 서버** — 같은 이유. 두 패키지 모두 이미 있지만
  클라이언트(`psql`·`redis-cli`)를 얻으려는 것이고, 서버는 colima/docker가 띄운다.
- **`localstack`** — AWS 전반(Lambda·SQS·DynamoDB…)을 흉내내는 큰 물건이다.
  지금 필요한 건 S3 하나라 `seaweedfs`로 충분하고, localstack은 도커 이미지를
  받아 도는 구조라 "컨테이너 없이"라는 이 묶음의 전제와도 어긋난다.

---

## 관련 문서

- [`README.md`](README.md) — 이 디렉토리(도구 안내서)의 인덱스
- [`backend-protocols.md`](backend-protocols.md) — 브로커·gRPC 클라이언트
- [`local-https-proxy.md`](local-https-proxy.md) — 도메인·쿠키·HTTPS 조건 재현
