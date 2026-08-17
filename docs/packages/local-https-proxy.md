# 로컬 HTTPS · 리버스 프록시

prod에서만 드러나는 **도메인·쿠키·HTTPS 조건**을 로컬에서 재현하는 도구 모음.
선언은 `modules/shared/packages.nix`의 "Infra / DB / network" 절에 있다
(`mkcert` / `caddy` / `cloudflared`).

---

## 왜 따로 필요한가

`localhost:3000` + `localhost:4000`으로 개발하면 잘 돌다가, prod에서
`app.example.com` + `api.example.com`으로 갈라지는 순간 깨지는 것들이 있다 —
cross-subdomain 쿠키(`crossSubDomainCookies`), `Secure`/`SameSite` 속성,
Safari ITP. 이 부류는 **포트가 아니라 도메인과 HTTPS가 있어야** 재현된다.

역할 분담:

| 도구 | 하는 일 |
|---|---|
| `caddy` | 리버스 프록시 + 자동 로컬 HTTPS (자체 로컬 CA) |
| `mkcert` | 로컬 신뢰 인증서 발급 — caddy 없이 dev 서버에 직접 꽂을 때 |
| `cloudflared` | 진짜 공인 HTTPS URL이 필요할 때 (웹훅, 실기기) |

---

## caddy — prod 토폴로지를 한 줄로

`*.localhost`는 OS가 알아서 127.0.0.1로 해석하므로 `/etc/hosts` 편집이 필요 없다.

```sh
# 가장 단순한 형태 — 프록시 하나
caddy reverse-proxy --from app.localhost --to :3000
# → https://app.localhost 가 바로 뜬다 (첫 실행 때 로컬 CA 신뢰 등록을 물어봄)
```

app/api 서브도메인 분리(Better Auth cross-subdomain 쿠키 재현)는 Caddyfile로:

```sh
cat > Caddyfile <<'EOF'
app.localhost {
    reverse_proxy :3000
}
api.localhost {
    reverse_proxy :4000
}
EOF
caddy run        # 포그라운드. 백그라운드는 caddy start / caddy stop
```

이 상태에서 `https://app.localhost` ↔ `https://api.localhost`가 서로 다른
오리진 + 같은 상위 도메인이 되어, `Domain=.localhost` 쿠키·CORS·`Secure`
속성이 prod와 같은 조건으로 걸린다. Safari ITP 우회용 rewrite(`/api/*` 를
same-origin으로 접기)도 같은 Caddyfile에 `handle_path`로 실험할 수 있다.

**인증서 신뢰**: caddy는 mkcert와 별개로 자체 로컬 CA를 만든다. 브라우저가
경고를 띄우면 `caddy trust`로 시스템 신뢰 저장소에 등록한다 (제거는
`caddy untrust`).

---

## mkcert — 프록시 없이 인증서만 필요할 때

dev 서버가 HTTPS 옵션을 직접 받는 경우(vite `--https` 등)는 프록시 없이
인증서만 꽂는 쪽이 단순하다.

```sh
mkcert -install                        # 로컬 CA를 신뢰 저장소에 (한 번만)
mkcert app.localhost "*.localhost"     # 현재 디렉토리에 pem 쌍 생성
```

---

## cloudflared — 공인 URL이 필요할 때

로컬 CA는 **이 기계**만 믿는다. 외부 서비스의 웹훅 콜백이나, CA를 설치할 수 없는
실기기(폰)에서 열어야 하면 터널로 진짜 HTTPS URL을 만든다.

```sh
cloudflared tunnel --url http://localhost:3000
# → https://random-words.trycloudflare.com (임시, 계정 불필요)
```

폰으로 넘길 때는 QR로 — [`mobile.md`](mobile.md)의 `qrencode` 레시피 참고.

---

## 함정

**HTTP/2 이하로 말하는 백엔드**: caddy는 업스트림에 기본 HTTP/1.1을 쓰므로
대부분 문제없지만, WebSocket은 Caddyfile의 `reverse_proxy`가 자동 업그레이드를
처리한다 — 별도 설정 불필요.

**`.localhost`가 아닌 커스텀 도메인**(`myapp.test` 등)을 쓰려면 그때는
`/etc/hosts`에 수동 등록이 필요하다. 가능하면 `.localhost`를 쓰는 게 마찰이 적다.

---

## 관련 문서

- [`README.md`](README.md) — 이 디렉토리(도구 안내서)의 인덱스
- [`mobile.md`](mobile.md) — 실기기(폰)에서 로컬 앱을 열어야 할 때
