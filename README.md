# nixos-config

> English: [README-EN.md](README-EN.md)

macOS(nix-darwin + home-manager)와 NixOS를 위한 개인 Nix 설정.

darwin 설정은 hostname이 아니라 **아키텍처**로 키잉된다: `aarch64-darwin`(Apple
Silicon), `x86_64-darwin`(Intel). 이 이름을 flake 타겟으로 쓴다 — 예: `.#aarch64-darwin`.

NixOS 설정은 **hostname**으로 키잉된다 — `mn56`, `galaxy-chromebook-1`(둘 다
`x86_64-linux`). 이 이름을 flake 타겟으로 쓴다 — 예: `.#mn56`. 호스트 디렉토리는 실제로
존재하는 머신만 만든다(그 머신에서 생성한 `hardware-configuration.nix`가 필요하다).
머신별 설정은 [NixOS 첫 빌드](#nixos-첫-빌드) 참고.

데스크톱 환경은 두 호스트 모두 greetd/tuigreet에서 **niri**(스크롤 타일링 +
Quickshell 셸, 기본)와 **GNOME / Wayland**(폴백) 두 세션을 고를 수 있다. 셸은
`local.niri.shell`로 DankMaterialShell / Noctalia 중 하나를 고른다 —
[modules/nixos/niri](modules/nixos/niri) 참고.

niri와 DMS의 *설정*은 Nix가 관리하지 않는다. `~/.config`의 평범한 쓰기 가능한
파일이라 저장하면 niri가 바로 리로드하고, DMS 설정 GUI도 정상 동작한다. 레포의
[modules/nixos/niri/rice](modules/nixos/niri/rice)는 백업 겸 새 머신용 시드이며
(없을 때만 복사된다), 살아있는 설정을 되받아 저장하는 건 `apps/rice-save`다.

룩은 프로필로 나눠 두었고 전환은 즉시 반영된다 — 재시작도 리빌드도 없다:

```sh
apps/rice-switch              # 현재 프로필 + 목록          (Mod+Shift+P = 다음 것)
apps/rice-switch frosted      # amoled | frosted | matugen
apps/rice-wall mountain       # ~/Pictures/Wallpapers 재귀 검색  (Mod+Shift+W)
apps/rice-wall --pick         # fuzzel 로 직접 고르기            (Mod+Ctrl+W)
```

한 프로필은 두 조각(`niri.kdl` / `dms.json`)이고, DMS 쪽만
전체 교체가 아니라 오버레이 병합이다 — `settings.json`에는 룩과 무관한 머신
상태가 섞여 있어서 통째로 갈면 그것까지 날아간다. `matugen` 프로필은 월페이퍼에서
색을 뽑아 셸·니리 보더·터미널 팔레트를 한 번에 맞춘다.

## 부트스트랩 — macOS (새 머신 최초 1회)

이 설정을 적용하면 `nix-command`와 `flakes`가 시스템 전역으로 켜진다(`nix.extraOptions`
→ `/etc/nix/nix.conf`). 그런데 닭-달걀 문제가 있다: 설정을 *적용*하려면 flake 명령을 써야
하고, 그건 이미 flakes가 켜져 있어야 한다. 그래서 **맨 처음 한 번**은 직접 flakes를
켜줘야 한다. 아래 중 하나를 고른다 — 머신당 한 번뿐이다.

1. **Nix 설치**(공식 multi-user 설치 프로그램):

   ```sh
   sh <(curl -L https://nixos.org/nix/install)
   ```

2. **첫 실행을 위해 flakes 켜기.** 아래 중 아무거나:

   - `/etc/nix/nix.conf`에 한 줄 추가(내가 쓰는 방법):

     ```sh
     echo 'experimental-features = nix-command flakes' | sudo tee -a /etc/nix/nix.conf
     # 그다음 nix-daemon 재시작(또는 새 셸 열기):
     sudo launchctl kickstart -k system/org.nixos.nix-daemon
     ```

   - …또는 파일 수정 없이 한 명령에만 적용:

     ```sh
     export NIX_CONFIG="extra-experimental-features = nix-command flakes"
     ```

   - …또는 첫 명령에만 인라인으로 전달:

     ```sh
     nix run --extra-experimental-features 'nix-command flakes' .#build-switch
     ```

3. **빌드 + 활성화:**

   ```sh
   nix run .#build-switch
   ```

첫 switch 이후에는 nix-darwin이 `/etc/nix/nix.conf`를 직접 관리하고(이 파일은
`/etc/static/nix/`로의 심링크가 된다) flakes를 계속 켜둔다. 그래서 위 1회성 단계는 이
머신에서 다시 필요 없다.

> 팁: [Determinate Systems 설치 프로그램](https://install.determinate.systems)은 flakes를
> 기본으로 켜줘서 2단계가 통째로 생략된다. 나는 공식 설치 프로그램을 써서 수동 단계가
> 남아 있다.

## NixOS 첫 빌드

위의 flakes 켜기 단계는 NixOS에서도 똑같이 적용된다(첫 flake 명령에
`--extra-experimental-features 'nix-command flakes'`가 필요). 거기에 더해, 첫 빌드 **전에**
반드시 정해야 하는 머신 고유 항목이 셋 있다:

1. **이 머신의 하드웨어 설정을 채운다.** 등록된 호스트(`mn56`,
   `galaxy-chromebook-1`)는 모두 그 머신에서 생성한 진짜
   `hosts/nixos/<host>/hardware-configuration.nix`를 갖고 있다. 새 머신을 추가할 때는
   호스트 디렉토리를 만들기 **전에** 이 파일부터 뽑는다 — 빈 placeholder를 커밋해두면
   `fileSystems` 미정의로 평가만 깨지고 얻는 게 없다:

   ```sh
   # 기존 NixOS 설치라면:
   cp /etc/nixos/hardware-configuration.nix hosts/nixos/mn56/hardware-configuration.nix
   # …또는 라이브 하드웨어 스캔으로:
   sudo nixos-generate-config --show-hardware-config > hosts/nixos/mn56/hardware-configuration.nix
   git add hosts/nixos/mn56/hardware-configuration.nix
   ```

   이 파일은 root/boot 파일시스템, swap, initrd 모듈, CPU 마이크로코드를 고정하므로 머신
   간에 공유할 수 없다.

2. **호스트를 고른다.** 호스트는 hostname으로 키잉된다(`mn56`,
   `galaxy-chromebook-1`). 더 추가하려면 `hosts/nixos/<name>/`를 만들고(`../common.nix` +
   자기 `hardware-configuration.nix`를 import) `flake.nix`의 `mkNixosHost` 목록에 등록한다.
   flake 속성 이름과 `networking.hostName`을 맞춰두면 `build-switch`가 호스트를 자동으로
   찾는다.

3. **SSH 접근 방식을 정한다.** `hosts/nixos/common.nix`는 `openssh`만 켜고 authorized key를
   선언하지 않으므로 계정 비밀번호(`passwd`로 설정) 로그인이 된다. 키 인증을 쓰려면
   `users.users.<user>.openssh.authorizedKeys.keys`에 본인 공개키를 넣는다.

그다음 빌드:

```sh
sudo nixos-rebuild switch --flake .#mn56      # 또는 .#galaxy-chromebook-1
# flakes가 켜져 있고 hostname이 호스트와 일치하면: nix run .#build-switch
```

> `nix flake check`는 NixOS 호스트까지 평가한다. 등록된 호스트가 전부 진짜
> hardware-configuration.nix를 갖고 있어야 통과하므로, placeholder 호스트를 남겨두면
> 여기서 `fileSystems` assertion으로 깨진다.

### 첫 switch 직후

**유저는 자동 생성되지만 비밀번호는 직접 설정해야 한다.** `common.nix`의 `users.users`가
계정을 선언하므로 activation이 `jh`를 만들어준다 — 홈 디렉토리 `/home/jh`, 셸 zsh,
`wheel`/`networkmanager`/`docker` 그룹까지 전부. 하지만 비밀번호는 레포 어디에도 선언돼
있지 않아서(`hashedPassword`/`initialPassword` 전부 null) 계정이 **잠긴 상태**로 생긴다.
tuigreet 로그인도, TTY 로그인도, `su - jh`도 안 된다. root로 한 번 풀어준다:

```sh
passwd jh
```

`users.mutableUsers`가 기본값 `true`라 이렇게 잡은 비밀번호는 이후 rebuild에도 유지된다.
해시를 선언해서 이 단계를 없앨 수도 있지만(`initialHashedPassword`), 공개 저장소라 권하지
않는다.

> root 셸에서 개발 도구가 안 보이는 건 정상이다. `modules/nixos/packages.nix`는
> home-manager의 `home.packages`로 들어가므로 `jh`의 프로필에만 깔린다. 시스템 전역
> (`environment.systemPackages`)에 있는 건 `common.nix`의 `gitFull`/`inetutils`와
> 호스트별 관찰 도구 정도다.

## 일상 사용

앱 스크립트(`apps/`)는 플랫폼 공유이고 런타임에 macOS/NixOS를 감지하므로, 같은 명령이
양쪽에서 동작한다:

```sh
nix run .#build-switch          # 새 generation을 빌드해 활성화
```

- **macOS** → `darwinConfigurations.<arch>`(예: `aarch64-darwin`)를 빌드·활성화.
- **NixOS** → `nixosConfigurations.<hostname>`을 활성화. 호스트는 `hostname`에서 가져오며,
  첫 switch 전에는 `nix run .#build-switch -- --host mn56`으로 덮어쓴다.
- **앞에 `sudo`를 붙이지 말 것.** 스크립트는 유저 권한으로 빌드한 뒤 활성화 단계에서만
  `sudo`를 부른다. 전체를 root로 돌리면 저장소의 git 소유권 검사가 깨진다.
- 추가 플래그는 그대로 전달된다 — 예: `nix run .#build-switch -- --show-trace`.

rebuild 도구를 직접 부르려면 설정 이름을 명시한다(맨 `.#`는 hostname으로 해석돼 arch
이름의 darwin 설정과 안 맞는다):

```sh
sudo darwin-rebuild switch --flake .#aarch64-darwin   # macOS
sudo nixos-rebuild  switch --flake .#mn56              # NixOS
```

## 그 밖의 flake 앱

```sh
nix run .#build               # 빌드만, 활성화 X (평가 검증용)
nix run .#rollback            # 이전 generation으로 복구
nix run .#clean               # 구 generation GC (기본 7d; 예: `-- 14d`)
```
