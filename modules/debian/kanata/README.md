# kanata — Debian(태블릿 tb323fu) 의 Caps Lock 레이어

NixOS 의 keyd 레이어(`modules/nixos/keyboard.nix` + `modules/nixos/pointer/`)를
[kanata](https://github.com/jtroo/kanata) 로 이 태블릿에 건다. 레이어 본체는 Windows 와
함께 쓰는 [`../../shared/kanata/nav.kbd`](../../shared/kanata/nav.kbd) 이고,
[`kanata.kbd`](kanata.kbd) 는 이 기기에만 해당하는 `defcfg` 와 기본 레이어를 두고
그것을 include 한다. 다른 점은 거기 주석에 있다.

Linux 의 kanata 는 uinput 으로 포인터를 직접 움직이므로 NixOS 처럼 `pointerd` 를
따로 띄우지 않는다. subline 은 kanata 의 가상 키보드(`kanata`)를 이름으로 알아보고
"물리 키보드가 붙었다"에 세지 않는다(subline `crates/compositor/src/input/devices.rs`
`is_remapper`).

## 설치

aarch64 Linux 용 릴리스 바이너리가 없고 crates.io 에도 1.12.0 이 없어서 태그에서
빌드한다.

```sh
git clone --depth 1 --branch v1.12.0 https://github.com/jtroo/kanata ~/build/kanata
cargo install --locked --path ~/build/kanata
sudo install -m755 ~/.cargo/bin/kanata /usr/local/bin/kanata
sudo install -m644 modules/debian/kanata/kanata.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now kanata
```

사용자가 `input` 그룹이어야 한다(`/dev/uinput` 이 `root:input 0660`).

## 확인

```sh
kanata --cfg modules/debian/kanata/kanata.kbd --check     # 문법만
journalctl -u kanata -b | grep registering                # 잡은 키보드
```

새 키보드가 잡히지 않거나 엉뚱한 장치가 잡히면 `kanata --cfg … --debug` 의
`Use for input autodetect` 줄을 보고 `linux-dev-names-exclude` 를 고친다.

키가 꼬이면 **왼쪽 Ctrl + Space + Esc**. 서비스는 `Restart=on-failure` 라 이렇게
끝내면 다시 뜨지 않는다 — `sudo systemctl start kanata`.
