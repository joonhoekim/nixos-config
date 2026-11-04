# Tailscale 과 원격 데스크톱

NixOS 기계들을 tailnet 에 붙이고, 그 위에서 다른 기계의 화면에 들어가는 법.

## 방향별로 무엇을 쓰나

| 방향 | 쓰는 것 | 받는 쪽에 필요한 것 |
|---|---|---|
| NixOS → Windows | Remmina (RDP) | Windows 의 원격 데스크톱. Pro 이상이어야 한다(Home 에는 RDP 서버가 없다) |
| Mac → NixOS | RustDesk | NixOS 에서 `rustdesk.service` 를 켠다(아래 "제어받는 쪽") |
| NixOS → Mac | Remmina (VNC) | macOS 의 화면 공유 |

NixOS 가 받는 쪽만 RustDesk 를 쓴다. 매일 쓰는 subline 세션에서 원격 입력을 넣을 수 있는 길이
지금은 RustDesk 의 uinput 경로뿐이기 때문이다. wayvnc 는 `zwlr_virtual_pointer_manager_v1` 이
필요한데, niri 에는 있고 subline 에는 없다. subline 이 이걸 갖추면 받는 쪽을 tailnet 주소만 듣는
wayvnc 로 바꾸고 RustDesk 를 걷어낼 수 있다. 그러면 root 서비스와 공용 중계 서버가 필요 없다.

## 무엇이 저장소에 있고 무엇이 없나

| | 어디 | 누가 관리 |
|---|---|---|
| `tailscaled`, `tailscale` CLI, 41641/udp | `modules/nixos/tailscale.nix` | nix (모든 NixOS 호스트) |
| tailnet 로그인 상태 | 각 기계의 `/var/lib/tailscale` | **손으로**, 기계마다 한 번 |
| RustDesk·Remmina 앱 | `modules/nixos/gui-apps.nix` 의 `rustdesk`, `remmina` | nix (`local.guiApps` 에 있는 호스트) |
| Mac 의 RustDesk | `modules/darwin/casks.nix` 의 `rustdesk` | nix (`local.casks` 에 있는 Mac) |
| 제어받는 쪽 서비스, tailscale0 의 21118/tcp | `modules/nixos/rustdesk.nix` | nix (위와 같은 호스트) |
| RustDesk ID·비밀번호·설정 | `~/.config/rustdesk`, `/root/.config/rustdesk` | 앱에서 |

auth key 를 식에 넣지 않는 이유는 [`wireguard.md`](wireguard.md) 와 같다. 공개 저장소이고,
식에 들어간 값은 `/nix/store` 에서 누구나 읽을 수 있다.

## Tailscale: 처음 한 번

```sh
sudo tailscale up            # 찍히는 URL 을 브라우저로 열어 로그인
tailscale status             # 다른 기계와 그 100.x 주소
tailscale ping <기계 이름>    # "via DERP" 이면 직접 연결이 안 된 것
```

로그인은 `/var/lib/tailscale` 에 남아 재부팅과 switch 를 넘는다. 기계를 다시 깔면 다시 한다.

DNS 는 systemd-resolved 없이 resolvconf 가 `/etc/resolv.conf` 를 쓴다. 이 조합에서 MagicDNS
를 켜면 tailscaled 가 그 파일을 직접 덮어쓴다. 이름 해석이 이상해지면 먼저
`cat /etc/resolv.conf` 로 누가 썼는지 본다.

## RustDesk: 접속하는 쪽 (Mac)

앱을 열고 상대의 ID 를 넣는다. 둘 다 tailnet 에 있으면 ID 대신 상대의 tailnet 주소
(`100.x.y.z` 또는 MagicDNS 이름)를 넣어도 된다. 이렇게 하면 RustDesk 공용 서버를 거치지 않는다.
이때 상대 쪽 설정 → 보안 → **직접 IP 접속 허용** 이 켜져 있어야 한다. 이 설정은 저장소가 아니라
상대 앱에 있다.

## RustDesk: 제어받는 쪽 (NixOS)

평소에는 꺼져 있다. 받을 때만 켜고, 다 쓰면 끈다.

```sh
sudo systemctl start rustdesk   # 앱 메인 화면의 서비스 시작 버튼도 같은 일을 한다(비밀번호를 묻는다)
sudo systemctl stop rustdesk
```

켜져 있는 동안에는 공용 중계 서버에 등록돼 ID 와 비밀번호로 접속을 받고, 메모리를 PSS 로 약
70 MiB 쓴다. 이 값은 mn56 에서 접속이 없을 때 잰 것이다. 앱의 버튼은 `systemctl enable` /
`disable` 도 같이 부른다. enable 은 경고만 내고, disable 은 읽기 전용 `/etc` 에 막혀 실패한다.
그래도 켜고 끄는 데는 영향이 없다.

`rustdesk.service` 는 root 로 `rustdesk --service` 를 띄운다. 그러면 이 프로세스가 seat0 사용자의
세션에 `rustdesk --server` 를 띄운다. `--server` 는 접속이 없으면 한 시간마다 스스로 다시 뜬다
(상류 `src/platform/linux.rs` 의 "restart server"). 상태는 `systemctl status rustdesk` 로 보고, 로그는
`/root/.local/share/logs/RustDesk/service/` 와 `~/.local/share/logs/RustDesk/server/` 에 있다.

Wayland 에서는 이 서비스가 있어야 입력이 들어간다. 서버 프로세스가 떠 있으면 RustDesk 는
화면을 xdg-desktop-portal 의 **ScreenCast** 로 받고, 입력은 자기 uinput 장치로 넣는다. 서버가
없으면 **RemoteDesktop** 포털을 쓰는데, 이 포털을 가진 세션은 GNOME 뿐이다.

| 세션 | ScreenCast | 서비스 없이 (RemoteDesktop) | 서비스로 (uinput) |
|---|---|---|---|
| subline | xdg-desktop-portal-wlr | 없음 | 가능 |
| niri | xdg-desktop-portal-gnome | 없음 | 가능 |
| Hyprland | xdg-desktop-portal-hyprland | 없음 | 가능 |
| GNOME | mutter | 있음 | 가능 |

알려진 제약:

- **접속할 때마다 화면 고르기 창이 뜬다.** ScreenCast 포털이 이 기계 앞에 있는 사람에게 묻는다.
  아무도 없는 기계에 들어가는 무인 접속은 Wayland 에서 안 된다.
- **화면이 둘 이상이면 하나만 보인다.** 상류 `src/server.rs` 에 "wayland does not support
  multiple displays currently" 라고 적혀 있다. uinput 마우스의 범위도 화면 하나 크기로 잡힌다.
  mn56(1920x1080 두 장, 하나는 세로)에서는 서버 로그에 `rng_x: (0, 1920), rng_y: (0, 1080)` 이
  찍혔다. 그래서 고르지 않은 화면 쪽은 포인터 위치가 어긋날 수 있다.
- 로그인 화면(greeter)에는 들어가지 못한다. 사용자 세션이 있어야 `--server` 가 뜬다.
