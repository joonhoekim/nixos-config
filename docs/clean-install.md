# 맨 땅에서 부팅까지 — NixOS 클린 설치

빈 기기에 이 레포의 설정을 얹어 부팅시키는 데까지의 기록. `evo-t1`(GMKtec EVO-T1)을
이 순서로 깔았고, 그때 실제로 걸린 것들을 그대로 적었다.

이 문서가 끝나는 지점은 **"내 설정으로 부팅해서 로그인했다"** 까지다. 그 뒤의 일상
운용(리빌드, 롤백, 라이싱)과 레포 쪽 규칙은 [README](../README.md)의 "NixOS 첫 빌드"
절과 [modules/nixos/README.md](../modules/nixos/README.md)의 "호스트 추가하기"에
있다. 겹치는 부분은 여기서 링크만 하고 다시 설명하지 않는다.

---

## 1. 준비

1. BIOS/펌웨어에서 **Secure Boot 끄기**. 안 끄면 서명 안 된 커널이 안 뜬다.
2. ISO를 굽거나 ventoy 같은 걸로 부팅 준비. 이 문서는 **minimal ISO** 기준이다.

## 2. 부팅 직후

부팅하면 `nixos` 유저로 자동 로그인된다. 루트 셸이 필요하다:

```bash
sudo -i
```

비밀번호는 안 묻는다. 설치 미디어는 `nixos`와 `root` 둘 다 빈 비밀번호로 만들어져
있고 `wheelNeedsPassword`가 꺼져 있다.

**네트워크가 필수다.** 유선이면 대개 이미 붙어 있으니 `ip a`로 확인만 하면 되고,
무선이면:

```bash
nmtui
```

minimal ISO에도 NetworkManager가 들어 있어서(`installation-device.nix`가
`networking.networkmanager.enable = true`) `nmtui`가 그냥 뜬다. 로그인 화면 안내문에도
같은 말이 적혀 있다.

설치 릴리스를 여기서 확인해 둔다. 나중에 `system.stateVersion`에 그대로 박을 값이다:

```bash
nixos-version    # 예: 26.05.20250xxx.xxxxxxx
```

## 3. 스토리지 셋업

디스크=storage로 표현하겠다. 디스크는 관례적인 표현이 되었기에...

`parted`보다 `cfdisk`가 훨씬 편하다.

```bash
lsblk                  # 현재 붙어 있는 물리 스토리지 확인
cfdisk /dev/nvme0n1    # 특정 스토리지의 파티션 TUI
```

NVMe SSD면 `nvme0n1`, `nvme1n1` 같은 형태다. `sda`, `sdb` 같은 건 USB나 HDD가 잡혀서
보이는 것. **설치 미디어 자신도 목록에 있으니** 대상을 잘못 고르지 않도록 용량으로
한 번 더 확인한다.

### 파티션 설계

**ESP 파티션과 파일시스템 파티션 두 개가 필수다.**

- ESP는 부트로더 파티션이라고 보면 된다. 부팅 시 어떤 Gen으로 부팅할지 목록을
  저장하는 것도 ESP다.
- 윈도우는 이 목적의 파티션이 100MB 정도다. 나는 NixOS는 스토리지에 여유가 있다면
  **2GB 정도** 잡아둔다. `systemd-boot`가 커널과 initrd를 여기에 두는데, 이 레포는
  `configurationLimit = 42`라 세대가 쌓이면 100MB로는 어림도 없다.
- 나는 스왑 파티션을 구성하는 경우를 제외하면 나머지를 FS 파티션 하나로 구성하는
  걸 선호한다. 리눅스 파티션을 엄격하게 구분해오던 걸 좋아한다면 그에 맞춰서 하면
  된다(root와 usr을 나누는 방식 등).

파티션 타입 GUID 끝 4자리 (cfdisk에서 타입 고를 때 확인용):

| 타입 | 끝 4자리 |
|------|----------|
| Linux filesystem | `7DE4` |
| EFI System | `C93B` |

### 스왑 파티션은 별로 추천하지 않는다

- hibernate를 안정화시켜 전체 메모리를 스토리지에 저장하려는 경우라면, 오프셋
  이슈를 피하기 위해 RAM 크기와 동일한 스왑 파티션을 고려할 수 있다.
- 그런데 이 hibernate 기능은 BIOS 셋업도 맞아야 하고, 복귀 시 hang 되어 버리는 문제를
  만날 확률이 꽤 있다. 약간의 SSD wear 비용도 발생한다. 이 레포에도 그 기록이 있다 —
  [`hosts/nixos/mn56/default.nix`](../hosts/nixos/mn56/default.nix)가 S4 복귀에서
  커널이 깨진 이야기를 길게 적어두고 있다.
- suspend 혹은 lock 방식에 idle 전력 관리가 경험상 더 편리했던 것 같다. 아예
  poweroff 하거나.
- 이 레포는 어차피 **zram을 RAM의 50%로 켠다**(`hosts/nixos/common.nix`). 64GB
  머신이면 그것만으로 32GB다. `evo-t1`은 스왑 파티션 없이 zram만으로 쓰고 있다.

파티션을 잡고 **Write** 한다. 파괴적인 작업이므로 주의. 작업 후 `lsblk`로 확인한다.

## 4. 포맷

EFI 파티션은 FAT으로 포맷해야 하지만, 리눅스 파일시스템용 파티션은 원하는 걸 고르면
된다. 여러 FS가 존재하지만 **ext4를 추천**한다. 특정한 목적이 있으면 btrfs 등을
고려할 수 있는데, 명확한 목적이 없다면 ext4. 그런 목적이 있다면 나중에 `disko`를
배워서 적용하는 게 좋다.

아래는 `/dev/nvme0n1p1`(EFI)과 `/dev/nvme0n1p2`(Linux FS)를 만들었다고 가정한다.
**p1과 p2를 헷갈리면 방금 만든 ESP를 ext4로 덮어쓴다.** 명령을 치기 전에 번호를 한 번
더 본다.

```bash
# FAT32 형식으로, boot 라는 라벨(-n 옵션)을 붙여 /dev/nvme0n1p1 을 포맷한다.
mkfs.fat -F 32 -n boot /dev/nvme0n1p1

# ext4 형식으로, nixos 라는 라벨(-L 옵션)을 붙여 /dev/nvme0n1p2 를 포맷한다.
mkfs.ext4 -L nixos /dev/nvme0n1p2
```

참고 두 가지:

- `mkfs.fat`은 대문자 `BOOT`를 권장하는데, 2010년 이전 정도로 아주 오래된 기기가
  아니면 별 상관 없다. 난 가독성과 자동완성을 위해 소문자 `boot`로 했다. NixOS 공식
  가이드도 소문자다.
- `mkfs.fat`과 `mkfs.ext4`는 유사해 보이지만 `mkfs`가 래퍼인 **아예 별개의 프로그램**
  이다. 그래서 `-n`(aming), `-L`(abeling) 같은 각 진영별 표현이 나뉘어져 깔끔하지가
  않다. `cfdisk`처럼 TUI가 있으면 좋겠지만 NixOS 설치 이미지에 포함된 대안을 찾지
  못했다.

## 5. 마운트

라벨을 붙여둔 덕에 `by-label`로 잡을 수 있다. 파티션 번호를 다시 세지 않아도 되니
여기서 실수가 줄어든다.

```bash
# Linux FS 부터. 아래는 만든 라벨이 nixos 인 경우다.
mount /dev/disk/by-label/nixos /mnt

# 그 안에 boot 경로를 만들어 ESP 를 마운트한다.
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
```

`lsblk`로 MOUNTPOINTS를 점검한다. `/mnt`와 `/mnt/boot` 둘 다 보여야 한다.

---

여기까지가 "빈 디스크를 쓸 수 있게 만드는" 부분이고, 아래부터가 **이 레포를 얹는**
부분이다.

## 6. 설정을 가져오는 두 갈래

관례적인 설치는 여기서 `nixos-generate-config --root /mnt`를 돌려
`/mnt/etc/nixos/`에 `configuration.nix`와 `hardware-configuration.nix` 두 개를 만들고,
그 `configuration.nix`를 손으로 고쳐서 설치한다.

이 레포처럼 설정이 이미 flake로 있으면 그럴 필요가 없다. **레포를 클론해서 거기에
`hardware-configuration.nix`만 새로 뽑아 넣고 그대로 설치**하면 된다. 다만 그 레포를
어디에 두느냐에 따라 뒤처리가 갈린다.

핵심은 이거다. 설치 중에는 타겟에 `jh` 유저가 아직 없다. 계정은 첫 activation 때
생기고, 그때 `/home/jh` **자기 자신만** `jh:users`로 넘어간다 —
`update-users-groups.pl`의 `createHome` 블록이 `chown`을 **재귀로 하지 않는다**. 그래서
설치 중에 root로 클론한 것은 그 안쪽이 root 소유로 남는다. 두 갈래는 이걸 언제
정리하느냐의 차이다.

### 갈래 A — 처음부터 홈 경로에 클론

한 번만 클론하고 끝내는 방식. **순서가 중요하다.**

```bash
# 1. 홈 경로를 만들고 클론한다 (아직 root 소유)
mkdir -p /mnt/home/jh
git clone https://github.com/joonhoekim/nixos-config /mnt/home/jh/nixos-config
cd /mnt/home/jh/nixos-config

# 2. (아래 7~9 절: hardware-configuration.nix 생성 → git add → nixos-install)

# 3. 설치가 끝난 뒤에 소유권을 넘긴다
chown -R 1000:100 /mnt/home/jh
```

- `git`은 minimal ISO에 이미 들어 있다(`installation-cd-base.nix`가
  `programs.git.enable`을 켠다). `nix-shell -p git` 안 해도 된다.
- 숫자로 `chown` 하는 이유: 설치 미디어의 `/etc/passwd`에는 `jh`가 없어서
  `chown jh:users`가 안 먹는다. NixOS는 일반 유저 uid를 **1000**부터, `users` 그룹은
  gid **100**으로 준다. `jh`가 이 머신의 첫 일반 유저면 1000이 맞다. 확신이 안 서면
  이 줄을 건너뛰고 **첫 부팅 후에** `sudo chown -R jh:users ~`를 하면 된다. 그쪽이
  확실하다.
- **`chown`을 `nixos-install` 전에 하지 말 것.** 설치는 root로 도는데, git은 남의
  소유인 레포를 만나면 `dubious ownership`으로 거부한다. 굳이 그 상황을 만들 이유가
  없다.

### 갈래 B — 루트에 클론하고 나중에 홈으로

설치 중에는 root의 홈에 두고, 부팅한 뒤 `jh`로 다시 가져오는 방식. `evo-t1`은 이쪽으로
했다.

```bash
# 설치 중 (루트 셸)
git clone https://github.com/joonhoekim/nixos-config /mnt/root/nixos-config
cd /mnt/root/nixos-config
# ... 7~9 절 진행 ...
```

부팅하고 `passwd jh`까지 끝낸 뒤, `jh`로 로그인해서:

```bash
# 방법 1 — 새로 클론한다. 소유권이 처음부터 맞는다.
#   단, /root 쪽에서 만든 커밋(= hardware-configuration.nix!)이
#   origin 에 push 되어 있어야 한다. 안 그러면 그 파일을 잃는다.
git clone https://github.com/joonhoekim/nixos-config ~/nixos-config

# 방법 2 — 있는 걸 그대로 옮긴다. push 안 한 커밋도 살아온다.
sudo cp -r /root/nixos-config ~/nixos-config
sudo chown -R jh:users ~/nixos-config
```

정리:

```bash
sudo rm -rf /root/nixos-config
```

### 어느 쪽을 쓸까

| | 갈래 A | 갈래 B |
|---|---|---|
| 클론 횟수 | 1회 | 2회 (또는 1회 + 복사) |
| uid 가정 | 필요 (1000) | 불필요 |
| 실수 지점 | `chown` 순서 | push 안 한 커밋 유실 |
| 뒤에 남는 것 | 없음 | `/root/nixos-config` |

A가 짧고, B가 안전하다. B로 갈 거면 **방법 2(cp + chown)** 를 권한다 — 커밋을 push
했는지 기억할 필요가 없다.

## 7. hardware-configuration.nix 뽑기

이 파일만은 **그 머신에서 생성한 진짜 파일**이어야 한다. 루트/부트 파일시스템, 스왑,
initrd 커널 모듈, CPU 마이크로코드를 고정하므로 머신 간에 공유할 수 없다.

레포 안에 호스트 디렉토리를 만들고(`<hostname>`은 `flake.nix`에 등록할 이름과 같게)
거기에 바로 뽑는다:

```bash
mkdir -p hosts/nixos/<hostname>
nixos-generate-config --root /mnt --show-hardware-config \
  > hosts/nixos/<hostname>/hardware-configuration.nix
```

`--show-hardware-config`는 stdout으로만 뱉는다. `--root /mnt` 없이 돌리면 설치 미디어
자신의 하드웨어를 스캔하니 주의.

**나온 파일을 한 번 읽어볼 것.** 디스크와 마이크로코드만 적히는 게 보통이지만 그
이상을 써넣을 때가 있다. `evo-t1`에서는 이런 줄이 딸려 나왔다:

```nix
hardware.cpu.intel.npu.enable = true;
```

NPU를 감지해서 켠 것인데 no-op이 아니다 — `intel-npu-driver` 펌웨어와 드라이버,
`level-zero`, 검증 도구까지 시스템에 깔린다. 원하지 않으면 지우면 되고, 두더라도
**무엇이 들어왔는지는 알고 있어야** 한다.

### git이 추적하지 않는 파일은 flake에 없는 것과 같다

```bash
git add hosts/nixos/<hostname>/hardware-configuration.nix
```

**이걸 빼먹으면 설치가 "file not found"로 죽는다.** `nixos-install --flake`는 인자를
`nix flake metadata`로 해석하는데, 로컬 git 레포는 `git+file://`로 잡히고 그건 **git이
추적하는 트리만** 본다. 파일이 디스크에 있어도 untracked면 flake 입장에서는 없는
파일이다.

커밋까지 할 필요는 없다(`git add`만으로 flake에 보인다). 다만 갈래 B의 방법 1로 갈
거면 커밋하고 push까지 해야 한다.

## 8. 호스트 등록과 stateVersion

`flake.nix`의 `nixosConfigurations`에 한 줄:

```nix
<hostname> = mkNixosHost ./hosts/nixos/<hostname>;
```

`hosts/nixos/<hostname>/default.nix`는 최소한 이렇게:

```nix
{ ... }:
{
  imports = [
    ../common.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "<hostname>";

  # 2절에서 확인한 nixos-version 의 릴리스를 그대로.
  system.stateVersion = "26.05";
}
```

`system.stateVersion`은 **설치에 쓴 릴리스**를 박는 값이지, 따라갈 채널이 아니다.
flake는 계속 nixos-unstable을 따라가므로 패키지는 그대로 최신이 된다.
`common.nix`가 `mkDefault`로 들고 있는 값은 이 레포 체크아웃이 마침 그 릴리스라는
뜻일 뿐, 새 설치가 받아야 할 값이 아니다.

flake 속성 이름과 `networking.hostName`을 같게 맞춰두면 `apps/build-switch`가 인자
없이도 호스트를 찾는다.

## 9. 설치

```bash
nixos-install --root /mnt --flake .#<hostname>
```

- **flakes를 따로 켤 필요 없다.** `nixos-install`은 `--flake`를 보면
  `--extra-experimental-features 'nix-command flakes'`를 자기가 붙여서 `nix`를 부른다.
  (`nix flake check` 같은 걸 직접 칠 거라면 그때는
  `export NIX_CONFIG="experimental-features = nix-command flakes"`가 필요하다.)
- `--root`의 기본값이 이미 `/mnt`라 생략해도 되지만, 명시하는 편이 낫다.
- 마지막에 **root 비밀번호를 묻는다.** 건너뛰려면 `--no-root-password`.

빌드가 한참 돈다. 이 레포는 GNOME + niri + Hyprland + DMS를 전부 깔기 때문에 받을 게
많다. 다만 전부 pinned nixpkgs에서 오므로 캐시를 타고, 로컬 컴파일은 거의 없다
(`galaxy-chromebook-1`만 예외 — 그 호스트는 커널 패치가 있어서 커널을 직접 빌드한다).

끝나면 언마운트하고 재부팅:

```bash
umount -R /mnt
reboot
```

설치 미디어를 뽑는 걸 잊지 말 것.

## 10. 첫 부팅

### 계정 잠금 풀기

**유저는 자동 생성되지만 비밀번호는 직접 설정해야 한다.** `common.nix`의
`users.users`가 계정을 선언하므로 activation이 `jh`를 만들어준다 — 홈 디렉토리, 셸,
`wheel`/`networkmanager`/`docker` 그룹까지. 하지만 비밀번호는 레포 어디에도 선언돼
있지 않아서(공개 저장소라 일부러 그렇다) 계정이 **잠긴 상태**로 생긴다. tuigreet
로그인도, TTY 로그인도, `su - jh`도 안 된다.

tuigreet 화면에서 `Ctrl+Alt+F2` 등으로 TTY를 열고 root로 로그인해서:

```bash
passwd jh
```

`users.mutableUsers`가 기본값 `true`라 이렇게 잡은 비밀번호는 이후 rebuild에도
유지된다.

### 소유권 정리

6절에서 미뤄뒀다면 지금 한다:

```bash
sudo chown -R jh:users ~/nixos-config
```

확인:

```bash
stat -c '%U:%G' ~/nixos-config ~/nixos-config/flake.nix
```

`root:root`가 나오면 아직 안 된 것이다. 안 고치면 `git`이 `dubious ownership`으로
거부하고 `apps/rice-save`류가 전부 막힌다. **`nix run .#build-switch`는 읽기만 해서
멀쩡히 돌아간다** — 그래서 한참 모르고 지나가기 쉬운 종류의 고장이다.

### 세션

tuigreet에서 세션을 고른다 — niri(기본), Hyprland(uwsm), GNOME(폴백). `--remember-session`
때문에 **두 번째 로그인부터는 마지막에 쓴 세션으로 자동으로 간다.**

### 일상 명령으로 넘어가기

```bash
cd ~/nixos-config
nix run .#build-switch
```

여기서부터는 [README](../README.md)의 "일상 사용"이 이어받는다.

---

## 걸리면 여기부터 본다

**설치 중에 `path ... does not exist` / `file not found`**
`git add`를 안 했다. 7절 끝을 볼 것. flake는 git이 추적하는 파일만 본다.

**설치 중에 `attribute 'evo-t1' missing`**
`flake.nix`의 `nixosConfigurations`에 호스트를 안 넣었거나 이름이 다르다.

**`infinite recursion` 또는 `fileSystems` assertion**
`hardware-configuration.nix`가 비었거나 placeholder다. 이 레포가 실제로 존재하는
머신만 호스트 디렉토리를 만드는 이유가 이것이다.

**설치는 됐는데 부팅 메뉴가 안 뜬다**
ESP를 `/mnt/boot`에 마운트한 채로 설치했는지 확인. 펌웨어의 부트 순서가 다른
디스크의 ESP를 먼저 잡는 경우도 있다 — `efibootmgr -v`로 보고 `efibootmgr -o`로
순서를 바꾸거나 `-b <ID> -B`로 죽은 항목을 지운다.

**재부팅하기 전에 뭔가 고치고 싶다**
설치 미디어에서 `nixos-enter --root /mnt`로 새 시스템 안에 들어갈 수 있다. 다시
깔 필요 없다.

**`nix-shell -p foo`가 "file 'nixpkgs' was not found in the Nix search path"**
`nix.nixPath`를 덮어쓴 설정이 있으면 이렇게 된다. 이 레포도 한동안 그랬다 —
`hosts/nixos/common.nix`의 `nix` 블록 주석에 전말이 있다.
