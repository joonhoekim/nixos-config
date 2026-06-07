# 11. `apps/` 디렉터리와 부트스트랩

`apps/`가 뭔지, Nix와 어떻게 연결되는지, 그리고 `%HOST%` 같은 플레이스홀더가
왜 커밋된 채로 들어있고 그 때문에 `nix flake check`가 왜 실패하는지.

> 참고: 디렉터리 전체 지도는 [02. 이 저장소의 구조](./02-repo-structure.md),
> flake의 일반 개념은 [08. flake 이해하기](./08-understanding-flakes.md).

## `apps/`의 정체: "내용은 bash, 진입은 Nix"

흔한 오해: "이건 그냥 clone할 때 돌리는 CLI 스크립트고 Nix와 무관하다."
→ **반은 맞고 반은 틀리다.**

- **내용**: `apps/<system>/` 안의 파일들은 평범한 **bash 스크립트**다. Nix 언어가 아니다.
- **진입**: 그 스크립트들은 flake의 **`apps` 출력**으로 노출되어 `nix run`으로 실행된다.

즉 Nix와 무관한 게 아니라, **Nix가 실행 진입점(`nix run .#<name>`)을 제공**하고
실제 일은 bash가 한다.

## 연결 고리 (`flake.nix`)

```nix
mkApp = scriptName: system: {
  type = "app";
  program = "${(writeScriptBin scriptName ''
    #!/usr/bin/env bash
    PATH=${git}/bin:$PATH                       # git을 PATH에 보장
    exec ${self}/apps/${system}/${scriptName}   # 실제 bash 스크립트 실행
  '')}/bin/${scriptName}";
};

apps = genAttrs linuxSystems  mkLinuxApps
    // genAttrs darwinSystems mkDarwinApps;
```

`writeScriptBin`(Nix 빌더)이 작은 래퍼를 만들어, `git`을 PATH에 넣은 뒤
`${self}/apps/<system>/<name>` 의 bash 파일을 `exec` 한다. `${self}`는 flake 소스 루트.

흐름:

```
nix run .#build-switch
  → apps.aarch64-darwin.build-switch  (flake 출력)
  → writeScriptBin 래퍼
  → apps/aarch64-darwin/build-switch  (실제 bash)
  → 내부에서 darwinConfigurations.aarch64-darwin 을 빌드·활성화
```

### 디렉터리 모양

```text
apps/
├─ aarch64-darwin/    Apple Silicon Mac
├─ x86_64-darwin/     Intel Mac
├─ x86_64-linux/      NixOS
└─ aarch64-linux  →   x86_64-linux  (심링크)
```

system마다 디렉터리가 따로다(상수 `SYSTEM_TYPE`가 박혀 있어서). 그래서 새 app을
추가하려면 각 system 디렉터리에 파일을 두고 `flake.nix`의 `mkDarwinApps`/`mkLinuxApps`에
`"name" = mkApp "name" system;` 한 줄씩 등록해야 한다.

## 각 app이 하는 일

| app | 용도 | 비고 |
|-----|------|------|
| `apply` | **부트스트랩(1회)**. 플레이스홀더 치환 | clone 직후 한 번. 대화형 |
| `build` | 빌드만 (활성화 X) | `nix build .#…system`, 결과 확인용 |
| `build-switch` | 빌드 + 활성화 | 일상 명령. `sudo darwin-rebuild switch` |
| `clean` | 구 세대 GC | `nix-collect-garbage --delete-older-than 7d` |
| `rollback` | 이전 세대로 복구 | 세대 번호 입력 (darwin 전용) |
| `*-keys` | SSH/GPG 키 생성·복사·확인 | `create-/copy-/check-keys` |

> 일상에서 실제로 자주 쓰는 건 `build-switch`. `apply`는 clone 직후 단 한 번이다.

## `apply` = 코드모드(codemod): 플레이스홀더 치환

`apply`는 단순 빌드 스크립트가 아니라 **소스 파일을 `sed`로 직접 고치는 코드모드**다.
clone 직후 한 번 돌려서, 템플릿에 박힌 토큰을 내 환경 값으로 바꾼다.

치환되는 토큰:

| 토큰 | 의미 | 채워지는 곳 |
|------|------|-------------|
| `%USER%` | 사용자명 | (양쪽 OS) |
| `%EMAIL%` / `%NAME%` | git 신원 | (양쪽 OS) |
| `%HOST%` | 호스트명 | NixOS 전용 |
| `%INTERFACE%` | 기본 네트워크 인터페이스 | NixOS 전용 |
| `%DISK%` | 부트 디스크 (disko 포맷 대상) | NixOS 전용 |

```bash
# apply 내부 (Linux 분기)
sed -i -e "s/%USER%/$USERNAME/g"      "$file"
sed -i -e "s/%HOST%/$HOST_NAME/g"     "$file"
sed -i -e "s/%DISK%/$BOOT_DISK/g"     "$file"
...
find . -type f -exec bash -c 'replace_tokens "$0"' {} \;
```

**핵심: macOS(Darwin) 분기는 `%HOST%`/`%INTERFACE%`/`%DISK%`를 일부러 건너뛴다.**
이 셋은 Linux 전용 값이라서다. 그래서 Mac에서 `apply`를 돌려도 NixOS 쪽
플레이스홀더 3개는 그대로 남는다.

현재 이 저장소에 남아있는 미치환 토큰:

```
hosts/nixos/default.nix:37   hostName = "%HOST%"
hosts/nixos/default.nix:39   interfaces."%INTERFACE%".useDHCP
modules/nixos/disk-config.nix:7   device = "/dev/%DISK%"
```

## 그래서 `nix flake check`가 실패한다 (의도된 동작)

`nix flake check`는 darwin뿐 아니라 **`nixosConfigurations`까지 전부 평가**한다.
위 `%HOST%`는 호스트명 정규식 타입 검사를 통과하지 못해서 평가가 거기서 터진다:

```
error: A definition for option `networking.hostName' is not of type
`string matching the pattern ...`. Definition values:
- In `…/hosts/nixos': "%HOST%"
```

이건 **버그가 아니라 템플릿 설계의 트레이드오프**다:

1. **이건 템플릿이다.** clone해서 자기 걸로 만드는 용도라, `apply`가 찾아 치환할 수
   있도록 플레이스홀더가 **커밋된 채로** 있어야 한다. 실제 값을 박아두면 모든
   사용자가 남의 호스트명·디스크를 clone하게 된다.
2. **`flake check`는 의도된 워크플로가 아니다.** 안내 경로는
   `nix run .#apply` → `nix run .#build-switch`이지 `flake check`가 아니다.
3. **`%HOST%`는 일부러 유효하지 않게 생겼다.** grep으로 찾기 쉽고 "여기 채워"가
   한눈에 보이도록. `"nixos"` 같은 유효 기본값은 check는 통과시키지만
   잘못된 호스트명/디스크로 빌드할 위험을 만든다(특히 `%DISK%`는 포맷 대상).

**중요: `darwin-rebuild switch`(`nix run .#build-switch`)와 일상 사용에는 영향이 없다.**
빨갛게 나오는 건 `nix flake check`뿐이다.

### 검증이 필요하면

darwin 설정만 평가해 보면 된다(플레이스홀더와 무관):

```bash
nix eval --raw '.#darwinConfigurations.aarch64-darwin.config.system.build.toplevel.drvPath'
```

> 플레이스홀더를 임시로 더미값(`%HOST%`→`check-host`, `%DISK%`→`sda` 등)으로
> 치환했다가 `flake check` 후 원복하는 "검증용 코드모드" 스크립트를 둘 수도 있다.
> (`%DISK%`는 평가만으로는 안 터지므로 더미값은 안전 — 실제 포맷은 빌드 시점에만.)

## 이 저장소(fork)에서의 선택

이건 더 이상 재배포할 템플릿이 아니라 **개인 fork**라, 메인테이너가 졌던
"남이 clone한다"는 제약이 없다. NixOS를 실제로 쓸 때 두 길 중 하나:

- **(A) 템플릿 방식 유지** — 실제 NixOS 머신에서 `nix run .#apply`로 3개 값을
  그 자리에서 채운다. 머신별 disk/interface를 의식적으로 고르게 되어 안전.
  Mac에서 `flake check`는 계속 실패로 남는다.
- **(B) 개인 설정으로 전환** — 호스트명을 정했다면 실제 값을 커밋. interface는
  `networking.useDHCP = true`로 명시를 없애고 disk만 실제 장치명으로. 그러면
  `flake check`도 통과한다.

어느 쪽이든 `%DISK%`는 **그 머신에서 신중히** 정한다(포맷 대상이라).
