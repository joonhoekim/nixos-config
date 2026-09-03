# 백엔드 프로토콜 도구

Nest 백엔드가 말하는 **curl로 닿지 않는 전송 방식** — 메시지 브로커와 gRPC — 를
셸에서 직접 찔러 보는 도구 모음. 선언은 `modules/shared/packages.nix`의
"Message brokers and gRPC" 절에 있다.

---

## 왜 필요한가

HTTP는 도구가 넘친다 (`xh`·`hurl`·`bruno`). 나머지 전송은 그렇지 않다. 브로커에
메시지가 실제로 들어갔는지, 컨슈머가 그것을 집었는지, gRPC 메서드가 무엇을
돌려주는지는 **애플리케이션 로그를 믿는 것 말고는 확인할 방법이 없어지기
쉽다.** 로그를 믿는다는 건 버그가 로그 코드에 있을 때 못 잡는다는 뜻이다.

이 도구들은 전부 그 반대편에 선다 — 애플리케이션 밖에서 브로커·서버에 직접
붙어서, 애플리케이션이 뭐라고 말하든 **거기 무엇이 있는지**를 본다.

---

## 무엇이 있나

| 도구 | 프로토콜 | 한 줄 |
|---|---|---|
| `kcat` | Kafka | 셸에서 produce/consume/메타데이터 (구 kafkacat) |
| `natscli` | NATS | `nats` — pub/sub, JetStream 스트림·컨슈머 관리 |
| `nats-top` | NATS | 연결별·subject별 트래픽 실시간 |
| `grpcurl` | gRPC | gRPC판 curl. 리플렉션이 켜져 있으면 `.proto` 없이 호출 |
| `buf` | protobuf | proto 린트, 기준선 대비 breaking change 검사, 코드 생성 |
| `ghz` | gRPC | gRPC 부하 생성기 |

WebSocket의 `websocat`은 [`browser-tooling.md`](browser-tooling.md) 쪽에 있다 —
보통 같은 개발 서버를 겨냥하게 되어서 그 묶음에 넣었다.

Redis는 별개다. `iredis`(자동완성 CLI)와 `redis`(`redis-cli`)가 같은 파일의 다른
절에 이미 있다.

---

## Kafka — `kcat`

### 먼저 브로커가 살아 있는지

```sh
kcat -b localhost:9092 -L            # 메타데이터: 토픽·파티션·리더
kcat -b localhost:9092 -L -t orders  # 토픽 하나만
```

`-L`이 답을 못 주면 그 아래 모든 문제는 연결 문제다. 여기서부터 시작할 것.

### 소비 (consume)

```sh
# 토픽 끝에서부터 새 메시지만
kcat -b localhost:9092 -t orders -C

# 처음부터 전부 읽고 끝나면 종료
kcat -b localhost:9092 -t orders -C -o beginning -e

# 최근 10건만
kcat -b localhost:9092 -t orders -C -o -10 -e

# 키·파티션·오프셋·타임스탬프까지 붙여서
kcat -b localhost:9092 -t orders -C -f 'p%p o%o k%k t%T: %s\n'
```

### 생산 (produce)

```sh
echo '{"orderId":"1"}' | kcat -b localhost:9092 -t orders -P

# 키를 붙여서 (파티셔닝 확인용) — -K 는 키/값 구분자
echo 'user-42:{"orderId":"1"}' | kcat -b localhost:9092 -t orders -P -K:
```

### 컨슈머 그룹으로 붙기

```sh
kcat -b localhost:9092 -G my-group orders
```

`-C`와 다르다. `-G`는 **오프셋을 커밋한다** — 즉 실제 컨슈머 하나로 참여한다.
디버깅 중에 무심코 쓰면 애플리케이션 컨슈머의 진도를 건드린다.

---

## NATS — `natscli`

### 컨텍스트를 먼저 만든다

접속 정보를 매번 플래그로 주는 대신 이름을 붙여 둔다.

```sh
nats context add local --server nats://localhost:4222 --select
nats context ls
```

### 기본

```sh
nats sub 'orders.>'                       # 와일드카드 구독
nats pub orders.created '{"id":1}'
nats req orders.lookup '{"id":1}'         # 요청/응답 — 응답이 안 오면 여기서 드러난다
nats server check connection              # 브로커 상태
```

### JetStream (영속 스트림)

Nest의 큐 기반 마이크로서비스가 실제로 쓰는 쪽이다.

```sh
nats stream ls
nats stream info ORDERS
nats stream view ORDERS                   # 저장된 메시지를 눈으로
nats consumer ls ORDERS
nats consumer info ORDERS my-consumer     # 미처리 개수·재전달 횟수
```

**`num_pending`과 `num_redelivered`가 진짜 답이 있는 자리다.** 컨슈머가 멈췄는지,
아니면 계속 실패해서 같은 메시지를 다시 받고 있는지가 여기서 갈린다.

```sh
nats-top -s localhost                     # 연결별 실시간 트래픽
```

---

## RabbitMQ는 왜 없나

nixpkgs가 `amqp-tools`를 뺐고, `rabbitmqadmin`은 단독 패키지가 아니라 브로커
패키지 안에 들어 있다. 브로커를 로컬에 깔 이유는 없으니 클라이언트만 따로 얻을
길이 마땅치 않다.

대신 **관리 API가 평범한 HTTP**라, 이미 있는 `xh`로 닿는다.

```sh
xh -a guest:guest :15672/api/overview
xh -a guest:guest :15672/api/queues
xh -a guest:guest :15672/api/queues/%2F/my-queue    # %2F 는 기본 vhost "/"
```

큐에서 메시지를 꺼내 보는 것도 된다 (`requeue: true`가 아니면 사라지니 주의).

```sh
xh -a guest:guest POST :15672/api/queues/%2F/my-queue/get \
   count:=1 ackmode=ack_requeue_true encoding=auto
```

---

## gRPC — `grpcurl`

### 서버가 무엇을 제공하는지

리플렉션이 켜져 있으면 `.proto` 파일이 필요 없다. NestJS gRPC 마이크로서비스는
기본으로 꺼져 있으니, 켜는 것부터가 첫 단계인 경우가 많다.

```sh
grpcurl -plaintext localhost:5000 list                    # 서비스 목록
grpcurl -plaintext localhost:5000 list orders.OrderService # 메서드 목록
grpcurl -plaintext localhost:5000 describe orders.OrderService.Get
```

`-plaintext`는 TLS 없이. 로컬 개발에서는 거의 항상 필요하다.

### 호출

```sh
grpcurl -plaintext -d '{"id":"1"}' localhost:5000 orders.OrderService/Get

# 리플렉션이 꺼져 있으면 proto 를 직접 준다
grpcurl -plaintext -import-path ./proto -proto orders.proto \
        -d '{"id":"1"}' localhost:5000 orders.OrderService/Get

# 스트리밍 요청 — 한 줄에 메시지 하나씩
echo '{"id":"1"}
{"id":"2"}' | grpcurl -plaintext -d @ localhost:5000 orders.OrderService/Watch
```

### 메타데이터 (헤더)

```sh
grpcurl -plaintext -H 'authorization: Bearer …' -d '{}' localhost:5000 svc.S/M
```

---

## protobuf — `buf`

`protoc`를 직접 다루는 것보다 이쪽이 낫다. 린트와 **breaking change 검사**가
붙어 있어서, proto 변경이 배포된 클라이언트를 깨는지 커밋 전에 판정된다.

```sh
buf lint                                  # 스타일·구조 규칙
buf format -w                             # 포맷
buf breaking --against '.git#branch=main' # main 대비 호환성 깨짐 검사
buf generate                              # buf.gen.yaml 대로 코드 생성
```

`buf breaking`이 이 도구를 넣은 진짜 이유다. **필드 번호 재사용이나 타입 변경은
컴파일은 통과하고 런타임에서 조용히 틀린 값을 준다** — 그걸 정적으로 잡는
유일한 수단이다.

---

## 부하

```sh
ghz --insecure --proto ./proto/orders.proto \
    --call orders.OrderService.Get \
    -d '{"id":"1"}' -n 2000 -c 50 localhost:5000

ghz --insecure --format json … > out.json   # 스크립트로 판정할 때
```

HTTP 쪽 대응물은 `k6`·`wrk`·`oha`다 ([`browser-tooling.md`](browser-tooling.md)).

---

## 함정

**브로커는 여기 없다.** 이 도구들은 전부 **클라이언트**다. Kafka·NATS·RabbitMQ
서버 자체는 컨테이너로 띄운다 (`docker`/`colima`가 이미 있다). 로컬에서 컨테이너
없이 세우는 의존물은 [`local-backing-services.md`](local-backing-services.md)
쪽이고, 브로커는 거기에도 없다 — 설정이 프로젝트마다 다른 물건이라 compose 파일이
정본인 편이 낫다.

**`kcat -G`는 오프셋을 커밋한다.** 위에 적었지만 되풀이할 값어치가 있다. 관찰만
하려면 `-C`를 쓴다.

**gRPC 리플렉션이 꺼져 있으면 `list`가 빈 응답이 아니라 에러를 낸다.**
`Failed to list services: server does not support the reflection API`가 나오면
서버 설정 문제지 연결 문제가 아니다. NestJS는 `GrpcOptions`에
`@grpc/reflection`을 붙여야 켜진다.

---

## 관련 문서

- [`README.md`](README.md) — 이 디렉토리(도구 안내서)의 인덱스
- [`browser-tooling.md`](browser-tooling.md) — HTTP·WebSocket 쪽 (`hurl`·`websocat`·`k6`)
- [`local-backing-services.md`](local-backing-services.md) — 로컬 의존 서비스 세우기
