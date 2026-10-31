# kanata — Caps Lock 레이어 (Windows · macOS)

[`kanata.kbd`](kanata.kbd) 하나를 Windows 와 macOS 가 같이 쓴다. **Caps Lock 을 홀드**하는
동안 오른손은 커서 이동([TouchCursor](https://github.com/martin-stone/touchcursor) 배치),
왼손은 마우스다. NixOS 는 아직 keyd + 전용 데몬으로 같은 배치를 건다
([`modules/nixos/keyboard.nix`](../../nixos/keyboard.nix),
[`modules/nixos/pointer/`](../../nixos/pointer/)) — 키 배치와 수치는 그쪽이 정본이다.

## 레이어

| 입력 | 결과 |
|---|---|
| Caps 탭 / 홀드 | Caps Lock / 레이어 |
| 레이어 + `i` `j` `k` `l` | ↑ ← ↓ → (역T) |
| 레이어 + `u` / `o` | 줄 처음 / 끝 — Windows Home/End, macOS ⌘← / ⌘→ |
| 레이어 + `h` / `n` | PageUp / PageDown |
| 레이어 + `p` / `m` | Backspace / Delete |
| 레이어 + `y` | Insert |
| 레이어 + `/` | 찾기 — Windows Ctrl+F, macOS ⌘F |
| 레이어 + `w` `a` `s` `d` (Shift: 저속) | 포인터 |
| 레이어 + `q` / `e` (Shift: 가로) | 휠 위 / 아래 |
| 레이어 + `f`·`8` / `r`·`0` / `9` | 왼쪽 / 오른쪽 / 가운데 버튼 (누르는 동안) |
| 한/영 | Windows 오른쪽 Alt (자판 배열이 처리), macOS 오른쪽 ⌘ → F18 |
| F열 (macOS) | 기본은 Media Keys(밝기·Mission Control·Spotlight·받아쓰기·재생·볼륨), fn 을 누르는 동안 Standard Function Keys. Windows 는 그대로 |

- 오른손 바인딩은 전부 unshifted 라서 Shift 는 통째로 **선택 확장**이다 — `Caps+⇧j` 는
  왼쪽으로 선택, `Caps+⇧o` 는 줄 끝까지 선택.
- Shift 저속은 이동 중에 눌러도 그 자리에서 걸린다(설정 파일의 `sl`/`sr` 주석).
- 매핑하지 않은 키는 홀드 중에도 제 글자가 나온다.
- 이 레이어는 단발 키만 보낸다. `d2w` 같은 조합이 안 되는 이유는
  [`modules/nixos/keyboard.nix.vim`](../../nixos/keyboard.nix.vim) 머리말.

macOS 포인터 속도는 실사용으로 맞췄고, 휠 양·방향은 아직 실측 전 초기값이다. 맞추는 자리는 `kanata.kbd` 의
`(platform (macos) ...)` 블록.

## 고치기

```sh
kanata --check -c modules/shared/kanata/kanata.kbd   # 지금 OS 의 블록만 검사한다
```

- **macOS** — `./apps/build-switch`. 설정이 스토어 경로로 데몬에 넘어가므로 파일이 바뀌면
  plist 가 바뀌고 nix-darwin 이 데몬을 다시 올린다.
- **Windows** — 레포의 파일을 직접 읽는다. 트레이 메뉴의 reload. 설치·자동 실행은
  [`modules/windows/kanata/README.md`](../../windows/kanata/README.md).

## macOS

배선은 [`modules/darwin/kanata.nix`](../../darwin/kanata.nix), 서명·설치는
[`apps/kanata`](../../../apps/kanata). 둘의 머리말에 이유가 있다. 요약하면:

- kanata 는 Karabiner-DriverKit-VirtualHIDDevice 드라이버로 키보드를 잡는다. 드라이버는
  `pkgs.kanata.passthru.darwinDriver` 판으로 nix 가 깐다. **Karabiner-Elements 는 같이 두지
  않는다** — 드라이버 데몬의 판이 다르고 키보드를 서로 잡으려 한다.
- kanata 와 드라이버 데몬은 root launchd 데몬이다(`org.nixos.kanata`,
  `org.nixos.karabiner-vhid-daemon`). 로그는 `/var/log/kanata.log`,
  `/var/log/karabiner-vhid-daemon.log`.
- 바이너리와 설정은 `/usr/local/libexec/kanata/` — 스토어의 것을 이 기계 신원으로 다시
  서명한 복사본이다. 그래야 kanata 판이 바뀌어도 TCC 허가가 남고, 부팅 때 `/nix` 가
  붙기 전에 떠도 죽지 않는다.

### 새 Mac, 또는 Karabiner-Elements 에서 넘어올 때

```sh
brew uninstall --cask karabiner-elements   # 깔려 있으면. cask 목록에서 뺀 것만으로는 안 지워진다
./apps/build-switch                        # 드라이버·데몬, 그리고 apps/kanata 까지
```

그다음 GUI 로 한 번:

1. 시스템 설정 > 일반 > 로그인 항목 및 확장 프로그램 > 드라이버 확장 —
   `org.pqrs.Karabiner-DriverKit-VirtualHIDDevice` 를 켠다(이미 켜져 있으면 그대로).
2. 시스템 설정 > 개인정보 보호 및 보안 > **입력 모니터링**과 **손쉬운 사용** —
   `/usr/local/libexec/kanata/kanata` 를 켠다. 목록에 없으면 `+` 로 넣는다(⌘⇧G 로 경로 입력).
   macOS 27 에서는 손쉬운 사용 목록이 **Device Control and Data Access** 라는 이름이다.
   입력 모니터링은 kanata 가 처음 뜰 때 스스로 목록에 올린다.
3. `sudo launchctl kickstart -k system/org.nixos.kanata`

확인은 `./apps/check/mac` 의 kanata 절, 안 되면 `/var/log/kanata.log`.

키가 꼬이면 **왼쪽 Ctrl + Space + Esc** 를 함께 누른다. kanata 내장 탈출구라 설정과
무관하게 종료된다(launchd 가 10초 뒤 다시 띄운다).
