# nixos-config

> English: [README-EN.md](README-EN.md)

macOS(nix-darwin + home-manager)와 NixOS를 위한 개인 Nix 설정.

darwin 설정은 hostname이 아니라 **아키텍처**로 키잉된다: `aarch64-darwin`(Apple
Silicon), `x86_64-darwin`(Intel). 이 이름을 flake 타겟으로 쓴다 — 예: `.#aarch64-darwin`.

NixOS 설정은 **hostname**으로 키잉된다 — `amd`, `intel`(둘 다 `x86_64-linux`). 이 이름을
flake 타겟으로 쓴다 — 예: `.#amd`. 머신별 설정은 [NixOS 첫 빌드](#nixos-첫-빌드) 참고.

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

1. **이 머신의 하드웨어 설정을 채운다.** 각 호스트는 *placeholder*
   `hosts/nixos/<host>/hardware-configuration.nix`를 갖고 있다 — 트리가 해석되도록 커밋돼
   있지만 일부러 `fileSystems`가 비어 있어서, 교체하지 않은 placeholder는 부팅 불가능한
   시스템을 만드는 대신 요란하게 실패한다. 타겟 머신에서 진짜 파일을 생성해 덮어쓴다:

   ```sh
   # 기존 NixOS 설치라면:
   cp /etc/nixos/hardware-configuration.nix hosts/nixos/amd/hardware-configuration.nix
   # …또는 라이브 하드웨어 스캔으로:
   sudo nixos-generate-config --show-hardware-config > hosts/nixos/amd/hardware-configuration.nix
   git add hosts/nixos/amd/hardware-configuration.nix
   ```

   이 파일은 root/boot 파일시스템, swap, initrd 모듈, CPU 마이크로코드를 고정하므로 머신
   간에 공유할 수 없다.

2. **호스트를 고른다.** 호스트는 hostname으로 키잉된다(`amd`, `intel`). 더 추가하려면
   `hosts/nixos/<name>/`를 만들고(`../common.nix` + 자기 `hardware-configuration.nix`를
   import) `flake.nix`의 `mkNixosHost` 목록에 등록한다.

3. **SSH 키를 교체한다.** `hosts/nixos/common.nix`에는 placeholder `sshKeys` 항목이 들어
   있다. 본인 공개키로 바꿔야 본인(과 root)이 로그인할 수 있다.

그다음 빌드:

```sh
sudo nixos-rebuild switch --flake .#amd      # 또는 .#intel
# flakes가 켜져 있고 hostname이 호스트와 일치하면: nix run .#build-switch
```

> `nix flake check`는 NixOS 호스트까지 평가하므로, 진짜 hardware-configuration.nix가
> 들어가기 전까지는 `fileSystems` assertion에서 실패한다. 의도된 동작이며 `build-switch`에는
> 영향이 없다.

## 일상 사용

앱 스크립트(`apps/`)는 플랫폼 공유이고 런타임에 macOS/NixOS를 감지하므로, 같은 명령이
양쪽에서 동작한다:

```sh
nix run .#build-switch          # 새 generation을 빌드해 활성화
```

- **macOS** → `darwinConfigurations.<arch>`(예: `aarch64-darwin`)를 빌드·활성화.
- **NixOS** → `nixosConfigurations.<hostname>`을 활성화. 호스트는 `hostname`에서 가져오며,
  첫 switch 전에는 `nix run .#build-switch -- --host amd`(또는 `--host intel`)로 덮어쓴다.
- **앞에 `sudo`를 붙이지 말 것.** 스크립트는 유저 권한으로 빌드한 뒤 활성화 단계에서만
  `sudo`를 부른다. 전체를 root로 돌리면 저장소의 git 소유권 검사가 깨진다.
- 추가 플래그는 그대로 전달된다 — 예: `nix run .#build-switch -- --show-trace`.

rebuild 도구를 직접 부르려면 설정 이름을 명시한다(맨 `.#`는 hostname으로 해석돼 arch
이름의 darwin 설정과 안 맞는다):

```sh
sudo darwin-rebuild switch --flake .#aarch64-darwin   # macOS
sudo nixos-rebuild  switch --flake .#amd              # NixOS
```

## 그 밖의 flake 앱

```sh
nix run .#build               # 빌드만, 활성화 X (평가 검증용)
nix run .#rollback            # 이전 generation으로 복구
nix run .#clean               # 구 generation GC (기본 7d; 예: `-- 14d`)
```
