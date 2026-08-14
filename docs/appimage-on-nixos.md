# AppImage와 NixOS — 왜 그냥 실행되지 않고, `appimage-run`이 무엇을 하는가

`modules/nixos/packages.nix`에 `appimage-run`이 들어 있는 이유와, 그것을 통해 앱을 돌릴 때
파일이 **어디에 생기는지**를 적는다. AppImage를 쓰다 보면 반드시 "이 파일 왜 여기 있지",
"어디를 고쳐야 하지"를 묻게 되는데, 그 답이 직관과 다르다.

실측값은 전부 evo-t1에서 LM Studio 0.4.21 AppImage로 확인한 것이다.

---

## 왜 NixOS에서만 실행이 안 되는가

AppImage 파일에 `file`을 걸면 이렇게 나온다.

```
ELF 64-bit LSB executable, x86-64, ... interpreter /lib64/ld-linux-x86-64.so.2, stripped
```

`interpreter /lib64/ld-linux-x86-64.so.2` — 이 한 줄이 전부다. 일반 배포판에는 이 경로에
동적 링커가 있지만 **NixOS에는 없다.** 모든 것이 `/nix/store` 안에 해시 경로로 들어가기
때문이다. 그래서 `chmod +x` 를 해도 `./foo.AppImage`는 실행되지 않는다.

```
zsh: no such file or directory: ./foo.AppImage
```

파일은 멀쩡히 있는데 "no such file"이라고 하는 이유가 이것이다. 없다고 하는 것은 AppImage가
아니라 **그것이 요구하는 인터프리터**다.

---

## AppImage의 정체

**파일 하나에 실행기와 파일시스템을 이어 붙인 것**이다. 설치라는 개념이 없고, 지우면 끝난다.

```
LM-Studio-0.4.21-2-x64.AppImage   1,089,837,856 bytes
├─ offset 0        \x7fELF   런처 ELF 바이너리        188,392 bytes (0.02%)
└─ offset 188392   hsqs      SquashFS 읽기 전용 이미지   나머지 전부
```

앞의 188 KB는 "뒤에 붙은 SquashFS를 마운트하고 그 안의 `AppRun`을 실행하라"는 일만 한다.
**자기 자신을 마운트하는 ISO**에 가깝다.

정체는 ELF 헤더의 패딩 자리에 적혀 있다.

```
offset 8, 9  = 0x41 0x49 = 'A' 'I'   AppImage 서명
offset 10    = 0x02                  타입 2 (SquashFS). 타입 1은 ISO9660
```

`appimage-exec.sh`가 실행 전에 이 바이트들을 검사하고(23-28행), 타입에 따라 `unsquashfs`(타입 2)
또는 `bsdtar`(타입 1)를 고른다. 페이로드 시작 위치는 파일 어딘가에 적혀 있는 게 아니라
**ELF 헤더에서 계산한다**(46행).

```
offset = e_shoff + e_shentsize × e_shnum     # 섹션 헤더가 끝나는 지점
```

즉 "ELF가 끝나는 곳부터가 SquashFS"다.

---

## `appimage-run`이 하는 일

FUSE 셀프 마운트를 포기하고 **압축을 풀어서 가짜 FHS 샌드박스 안에서 실행한다.**

1. SquashFS를 `$XDG_CACHE_HOME/appimage-run/<sha256>/`에 추출한다
2. `bwrap`으로 `/usr`, `/lib64`, `/bin/bash`, `/etc` 같은 것을 만들어 낸 샌드박스를 구성한다
3. 그 안에서 `AppRun`을 실행한다

nixpkgs의 패키지 이름이 `appimage-run-bwrap`인 이유다. 호스트에서 빌려오는 것도 있다 —
`/etc/fonts`, `/etc/ssl/certs`, 그리고 `/nix`와 최상위 디렉터리들(`/mnt` 포함)이 bind mount 된다.
**`/mnt/ai` 같은 별도 디스크에 데이터를 두어도 샌드박스 안에서 그대로 보인다.**

첫 실행이 느린 것은 이 구조의 대가다. LM Studio는 1.1 GB AppImage에서 746 MB를 푼다.

### 샌드박스 안에서만 유효한 것들

추출된 트리 안에는 `#!/usr/bin/bash` 같은 shebang을 가진 스크립트가 흔하다. 호스트 셸에서
직접 실행하면 이렇게 된다.

```
bad interpreter: /usr/bin/bash: no such file or directory
```

**고장이 아니라 실행 위치가 틀린 것이다.** 그 경로는 bwrap 안에만 존재한다. 샌드박스 안에서
임의 명령을 돌려 보려면 전용 손잡이가 있다.

```sh
APPIMAGE_DEBUG_EXEC=/bin/bash appimage-run ./foo.AppImage
```

---

## 세 계층 — 어디를 고쳐야 하는가

AppImage 앱에서 무언가를 고쳐야 할 때, 대상이 어느 층인지 먼저 정해야 한다.

```
① AppImage 파일         ~/Downloads/Foo.AppImage
   불변. 절대 수정 대상이 아니다.
                             │ appimage-run 이 추출
                             ▼
② 추출 캐시              $XDG_CACHE_HOME/appimage-run/<sha256>/
   AppRun, 번들 라이브러리 … 일회용 사본.
   지워도 무방(재추출된다). 고쳐도 다음 버전에서 조용히 사라진다.
                             │ 앱이 첫 실행 때 복사·다운로드
                             ▼
③ 사용자 데이터           ~/.config/<앱>, 앱 고유 홈(~/.lmstudio 등)
   설정, 런타임, 플러그인. ★ 고칠 일이 있으면 거의 항상 여기다.
```

②와 ③의 경계는 로그에 드러난다. LM Studio는 시작할 때 이렇게 말한다.

```
[BundledDepsUnpackager] Unbundling engines from the app installer...
  (<추출캐시>/resources/app/.webpack/bin/extensions/backends
   -> <앱 홈>/extensions/backends)
```

②에서 ③으로 **복사**하는 것이다. 그래서 `_amphibian` 같은 런타임 디렉터리는 ②에 없고 ③에만
있다. 앱이 "자기 파일"이라고 여기는 것의 상당수가 실은 첫 실행 때 만들어진 사용자 데이터다.

**①을 수정하는 것은 사실상 하면 안 되는 일이다.** 파일 하나를 통째로 다시 만들어야 하고,
서명이 깨지고, 업데이트하면 전부 날아간다.

---

## 추출 캐시는 무엇으로 주소지정되나

`appimage-exec.sh`의 65-66행이 전부다.

```bash
SHA256=$(sha256sum "$APPIMAGE" | awk '{print $1}')
export APPDIR="${XDG_CACHE_HOME:-$HOME/.cache}/appimage-run/$SHA256"
```

경로가 **독립적인 두 조각**으로 조립된다.

| 조각 | 결정 요인 | 성격 |
|---|---|---|
| 부모 디렉터리 | `$XDG_CACHE_HOME`, 없으면 `$HOME/.cache` | 환경변수 |
| 말단 디렉터리명 | AppImage **파일 내용**의 SHA256 | 파일 자체 |

따라오는 성질들:

- **현재 작업 디렉터리(CWD)는 무관하다.** 어디서 실행하든 같은 곳에 풀린다.
  (스크립트가 `OWD`를 export 하지만 그건 AppImage 규격이 정의한 "원래 작업 디렉터리"를
  앱에 넘기는 것이고 캐시 경로와 무관하다.)
- **파일명도 무관하다.** 이름을 바꿔도 캐시는 같다. 반대로 이름이 같아도 내용이 다르면
  (= 버전 업) 다른 디렉터리가 된다.
- **AppImage 자신은 캐시에 대해 아무것도 정하지 않는다.** 포맷에 캐시라는 개념이 없다.
  앱은 `APPDIR`을 **받는** 쪽이지 고르는 쪽이 아니다.

71행이 캐시 히트를 판정한다 — `if [ ! -x "$APPDIR" ]`. 히트하면 추출을 건너뛴다. 로그 첫
줄로 구분할 수 있다.

```
Uncompress Foo.AppImage of type 02 @ offset 188392   ← 미스: 지금 푸는 중
Foo.AppImage installed in /…/appimage-run/1014376d…  ← 히트: 재사용
```

수동 지정도 있다. `-x <dir>`는 지정 디렉터리에 추출만 하고 종료, `-w <dir>`는 이미 풀린
디렉터리를 실행한다(`appimageTools`가 쓰는 경로다).

### 다른 배포판과 다르다

일반 배포판에서 타입 2 AppImage는 FUSE로 `/tmp/.mount_XXXXXX`에 자기를 마운트했다가 종료 시
언마운트한다. **영속 캐시가 아예 생기지 않는다.** 위의 SHA256 캐시는 nixpkgs가 도입한 것이다.

---

## 캐시 운영 — 자동 정리는 없다

`appimage-run`은 옛 캐시를 **절대 지우지 않는다.** 앱을 업데이트하면 해시가 바뀌어 새
디렉터리에 다시 풀리고, 옛 버전 캐시는 영원히 남는다. LM Studio 기준 버전당 746 MB다.

지우는 것은 안전하다. 잃는 것은 다음 실행의 추출 시간뿐이다.

```sh
du -sh "${XDG_CACHE_HOME:-$HOME/.cache}"/appimage-run/*   # 뭐가 쌓였나
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}"/appimage-run/*   # 전부 비우기
```

지금 쓰는 AppImage의 캐시만 남기려면 해시로 대조한다.

```sh
sha256sum ~/Downloads/*.AppImage | awk '{print $1}'       # 살릴 디렉터리 이름
```

---

## 실전: 앱이 만드는 것을 전부 다른 디스크로 보내기

evo-t1에서 LM Studio를 `/mnt/ai`(로컬 추론용 스크래치 디스크)에 통째로 얹은 구성이다.
앱이 쓰는 곳이 셋이고 **각각 제어 수단이 다르다**는 게 요점이다.

| 대상 | 크기 | 수단 |
|---|---|---|
| 추출 캐시 | 746 M | `XDG_CACHE_HOME` |
| Electron userData (`~/.config/LM Studio`) | 2.5 M | `XDG_CONFIG_HOME` |
| 앱 홈 (`~/.lmstudio`) — 모델·런타임 | 1.8 G | `~/.lmstudio-home-pointer` (앱 고유 기능) |

`~/.local/bin/lm-studio`가 셋을 한 번에 처리한다. 핵심만 옮기면:

```sh
export XDG_CACHE_HOME=/mnt/ai/cache
export XDG_CONFIG_HOME=/mnt/ai/config
printf '%s' /mnt/ai/lmstudio > "$HOME/.lmstudio-home-pointer"
exec appimage-run "$APPIMAGE" "$@"
```

`XDG_*`를 런처 안에서만 export 하므로 시스템의 다른 앱은 영향받지 않는다. 런처는 시작 전에
`mountpoint -q /mnt/ai`로 마운트를 확인하고, 없으면 **실행을 거부한다** — 디스크가 빠진 채로
앱이 조용히 홈에 2.5 GB를 다시 만드는 것을 막기 위해서다(`/mnt/ai`는 `nofail`로 붙는다).

### 심볼릭 링크로 하지 말 것

`~/.lmstudio`를 다른 디스크로 심볼릭 링크하는 방법이 먼저 떠오르지만, 이건 **새는 추상화**다.
앱이 `realpath`로 해석한 절대경로를 설정 파일에 기록해 버리면, 나중에 링크를 없애는 순간
그 기록들이 전부 어긋난다. Python venv의 `pyvenv.cfg`처럼 prefix를 파일에 굽는 것들이 특히
그렇다. 앱이 경로 설정을 제공한다면 **그쪽을 쓴다.**

실제로 겪은 전말은 [2026-08-15 사후 기록](postmortems/2026-08-15-lm-studio-appimage-paths.md)에 있다.

---

## 요약

- NixOS에서 AppImage가 안 도는 것은 `/lib64/ld-linux-x86-64.so.2`가 없어서다. `appimage-run`을 쓴다.
- AppImage = ELF 런처 + SquashFS를 이어 붙인 파일 하나. 자기 자신을 마운트하는 ISO.
- `appimage-run`은 마운트 대신 **추출 + bwrap FHS 샌드박스**로 돌린다.
- 캐시 경로 = `XDG_CACHE_HOME`(환경) + AppImage 내용의 SHA256(파일). **CWD·파일명 무관.**
- 고칠 일이 생기면 대상은 거의 항상 **③ 사용자 데이터**다. ①은 불변, ②는 일회용.
- 캐시는 자동 정리되지 않는다. 버전마다 쌓인다.
