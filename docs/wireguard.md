# WireGuard 클라이언트

외부 WireGuard 서버에 이 기계들을 클라이언트로 붙이는 절차. 서버는 이 저장소
밖에 있고, 여기서는 받는 쪽만 다룬다.

## 무엇이 저장소에 있고 무엇이 없나

| | 어디 | 누가 관리 |
|---|---|---|
| `wg`, `wg-quick` | `modules/shared/packages.nix` 의 `wireguard-tools` | nix (양 플랫폼) |
| 부팅 시 `wg0` 자동 연결 | `modules/nixos/wireguard.nix` | nix (NixOS 만) |
| 터널 설정 + 개인키 | 각 기계의 `/etc/wireguard/wg0.conf` | **손으로**, 기계마다 |

설정 파일이 저장소에 없는 이유: 공개 저장소이고, nix 식에 들어간 값은
`/nix/store` 에도 누구나 읽을 수 있게 남는다. 개인키는 기계를 떠나지 않는다.

## 설정 파일 넣기 (양 플랫폼 공통)

서버에서 받은 `.conf` 를 권한 600 으로 복사한다.

```sh
sudo install -d -m 700 /etc/wireguard
sudo install -m 600 ~/Downloads/wg0.conf /etc/wireguard/wg0.conf
```

`sudo $EDITOR /etc/wireguard/wg0.conf` 로 새로 만들면 umask 때문에 644 가 되고,
`wg-quick` 이 `Warning: ... is world accessible` 를 낸다. 편집기로 만들었다면
`sudo chmod 600` 을 한 번 더 친다.

인터페이스 이름은 **파일 이름**에서 온다. `wg0.conf` 가 아니면 NixOS 의 자동 연결
유닛이 찾지 못한다(아래).

## NixOS

`wg-quick-wg0.service` 가 부팅 때 터널을 올린다. 켜고 끄는 것도 이 유닛으로 한다.

```sh
sudo systemctl start   wg-quick-wg0
sudo systemctl stop    wg-quick-wg0
sudo systemctl restart wg-quick-wg0   # wg0.conf 를 고친 뒤 — rebuild 는 필요 없다
systemctl status wg-quick-wg0
sudo wg show                           # latest handshake 가 찍혀야 붙은 것
```

- **`sudo wg-quick up/down wg0` 을 직접 치지 않는다.** 유닛 밖에서 올리면 유닛이
  모르는 `wg0` 이 생기고, 다음 `systemctl start` 나 `build-switch` 가
  `wg0 already exists` 로 실패한다. 이미 손으로 올려 둔 상태라면
  `sudo wg-quick down wg0` 으로 내린 뒤 `systemctl start` 한다.
- `/etc/wireguard/wg0.conf` 가 없는 기계에서는 유닛이 조건 불충족으로 조용히
  건너뛴다(`systemctl status` 에 `Condition: start condition unmet`). 에러가 아니다.
- `Endpoint` 가 IP 가 아니라 도메인이면, 부팅 때 Wi-Fi 가 붙기 전에 유닛이 뜨면
  이름 풀이에 실패해 `failed` 로 남는다. 재시도하지 않으므로 네트워크가 붙은 뒤
  `sudo systemctl restart wg-quick-wg0` 을 한 번 친다.
- 그 기계에서 자동 연결을 끄고 싶으면 파일 이름을 바꾼다
  (`wg0.conf` → `wg0.conf.off`). `systemctl disable` / `mask` 는 NixOS 가 관리하는
  유닛이라 먹지 않는다.

NetworkManager(`nmcli connection import type wireguard ...`)로도 붙일 수 있지만
쓰지 않는다. 설정이 NetworkManager 쪽에 사본으로 한 벌 더 생기고, 같은 `wg0` 을
두고 위 유닛과 충돌한다.

## macOS

nix-darwin 에는 wg-quick 모듈이 없어서 자동 연결은 없다. 손으로 올리고 내린다.

```sh
sudo wg-quick up wg0
sudo wg-quick down wg0
sudo wg show
```

`wg-quick` 은 `/etc/wireguard/` 에서 `wg0.conf` 를 찾는다. 커널 모듈 대신
`wireguard-go` 가 `utunN` 인터페이스를 만드는데, nixpkgs 의 wrapper 가
`wireguard-go` 를 PATH 에 넣어 주므로 따로 깔 것은 없다.

`sudo` 가 `wg-quick` 을 못 찾으면(`command not found`) 경로를 풀어서 넘긴다.

```sh
sudo "$(command -v wg-quick)" up wg0
```

App Store 의 WireGuard 앱(`modules/darwin/home-manager.nix` 의 주석 처리된
`masApps` 항목)과 동시에 쓰지 않는다 — 같은 터널을 둘이 올리면 라우팅이 꼬인다.

## 붙었는지 확인

```sh
sudo wg show            # latest handshake 가 2분 이내, transfer 가 늘어나야 한다
ping <서버 쪽 터널 IP>
curl -s ifconfig.me     # AllowedIPs = 0.0.0.0/0 (전체 터널)일 때만 서버 IP 로 바뀐다
```

`latest handshake` 줄이 아예 없으면 패킷이 서버에 닿지 않는 것이다. `Endpoint` 의
주소·포트, 서버 쪽에 이 기계의 공개키(`sudo wg show wg0 public-key`)가 등록됐는지,
중간 네트워크가 UDP 를 막는지 순서로 본다.
