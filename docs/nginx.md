# nginx — 선언적 패키지, 명령형 설정

`modules/nixos/nginx.nix` 는 mn56 에서 회사 업무 앱의 폐쇄망 dev/qa 서버 앞 리버스 프록시를 재현한다. 목적은 프록시
동작(WebSocket 업그레이드, 정적 단락, TLS)을 개발 중에 찔러 보는 것이다. import 하는 호스트는 [mn56](hosts/mn56.md)뿐이다.

## 왜 services.nginx 가 아닌가

NixOS 모듈 `services.nginx` 는 설정 전체를 /nix/store 에 만들고 `nginx -c /nix/store/...` 로 돌린다. 읽기 전용이라 한
줄 바꾸는 데 rebuild 가 든다. 이 nginx 는 정반대가 필요하다. 설정은 앱 레포(`scripts/nginx/configs/<role>/`)에 정본이
있고, 그 레포의 deploy-nginx.sh 가 적용한다 — 백업, 스테이징, `nginx -t`, 그다음 reload, 실패하면 백업 복원.

| | 누가 | 무엇 |
|---|---|---|
| 선언적 | 이 모듈 | 패키지, systemd 유닛, 디렉터리, mime.types |
| 명령형 | `/etc/nginx` | nginx.conf, conf.d/*.conf, ssl/* |

적용 `cd <app repo>; bash scripts/nginx/deploy-nginx.sh apply local`, 미리보기 `diff local`.

## -c 래퍼

nixpkgs 는 --conf-path 없이 빌드해 기본 설정이 `<store>/conf/nginx.conf` 다. Debian/RHEL 은
--conf-path=/etc/nginx/nginx.conf 라 맨 `nginx -t` 가 /etc/nginx 를 검사한다. 여기선 스토어의 기본 설정을 검사해 통과해
버리므로, 맨 `nginx -t` 를 돌리고 실패하면 복원하는 deploy-nginx.sh 의 안전장치가 조용히 무력해진다. 그래서 `-c
/etc/nginx/nginx.conf` 를 붙인 래퍼로 감싼다. --add-flags 는 호출자 인자 앞에 붙고 nginx 는 마지막 -c 를 따르므로
`nginx -t -c /somewhere/else.conf` 도 된다. 임시 경로는 nixpkgs 가 /tmp/nginx_* 절대 경로로 둬서 고칠 게 없다(상대였다면
-p 로 접두어도 옮겨야 했다).

## 인증서

mkcert(로컬 CA 를 만들어 개발용 인증서를 발급하는 도구) 인증서는 발급한 CA 의 머신에서만 믿어진다(가져온 것은 다시 발급할
때까지 경고). nssTools(certutil)는 `mkcert -install` 이 신뢰 저장소에 닿는 길이고, 다른 길(/usr/local/share/ca-certificates
+ update-ca-certificates)은 NixOS 에 없다. 그래서 Chrome·Firefox(~/.pki/nssdb)만 덮고 OpenSSL 소비자(curl, node)는 안
덮는다. 그걸 믿게 하려면 security.pki.certificateFiles 에 CA 를 선언해야 하는데, flakes 에서는 레포 안 경로라 공개
GitHub 에 신뢰 앵커를 올리는 셈이다. `curl -k` 를 위해 그럴 가치는 없다 — SSL_CERT_FILE / NODE_EXTRA_CA_CERTS 를 쓴다.

## 유닛

- 설정이 없으면 ConditionPathExists 로 건너뛴다(부팅마다 실패 유닛이 남지 않게).
- ExecStartPre `nginx -t`: 시작 시도보다 메시지가 분명하다.
- daemon off 로 master 를 직접 추적한다(pid 파일을 쓰면 유닛의 PIDFile 과 손으로 고치는 nginx.conf 의 `pid` 가 늘
  맞아야 한다). 같은 이유로 reload 는 HUP(`nginx -s reload` 는 pid 파일을 읽는다). deploy-nginx.sh 는 `systemctl reload nginx`.
- master 는 80/443 바인드 때문에 root, worker 는 nginx.conf 의 `user`.
- PrivateTmp 를 끈다(/tmp/nginx_*).
- /var/log/nginx 는 컴파일된 --error-log-path 라 없으면 안 뜬다.
- 디렉터리를 environment.etc 로 안 두는 건 읽기 전용 심링크가 되어서다. mime.types 만 아무도 안 고치는 정적 자산이라
  스토어에 링크해 패키지와 맞춘다.
- 방화벽은 닫는다(브라우저·Playwright 는 loopback). LAN 의 다른 기기가 닿아야 할 때만
  `networking.firewall.allowedTCPPorts = [ 80 443 ];`. libvirt 게스트가 그 예외다 — virbr0 에만 443
  ([Windows 게스트](windows-guest.md#네트워크)).
