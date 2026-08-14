# 2026-08-15 — evo-t1: 안 켜진 줄 알았던 앱과, 심볼릭 링크가 구워 놓은 절대경로

환경: NixOS 26.11, Hyprland 0.56.2 (Wayland), LM Studio 0.4.21 AppImage,
`appimage-run`(bwrap), Intel Arc Pro 130T/140T.

남는 NVMe를 `/mnt/ai`로 세우고 LM Studio를 그 위에 얹는 작업에서 셋이 조용히 어긋났다.
셋 다 에러 메시지가 없었고, 하나는 **진단하려고 띄운 것이 증상을 만들었다.**

구조 설명은 [AppImage와 NixOS](../appimage-on-nixos.md)에 따로 있다. 여기는 고장만 적는다.

---

## 증상 1 — "`appimage-run`으로 안 켜진다"

실제로는 켜지고 있었다. 그냥 **느렸다.**

콜드 스타트에서 창이 뜨기 전에 끝나야 하는 일이 셋이다.

1. `appimage-run`이 1.1 GB AppImage에서 746 MB를 푼다
2. LM Studio가 llama.cpp 런타임 팩을 받아 전개한다 (1.8 GB)
3. 번들 플러그인 unbundling, vendor Python 바이트컴파일

그동안 터미널에는 로그만 흐르고 화면에는 아무것도 없다. 멈춘 것으로 보고 Ctrl+C 하기 딱
좋다. 캐시가 찬 뒤로는 **창이 5초 안에** 뜬다.

### 확인법: 창이 진짜 없는지 컴포지터에 직접 묻는다

"안 뜬다"를 눈으로 판단하지 않는다. 워크스페이스가 다르거나 아직 매핑 전일 수도 있다.

```sh
hyprctl clients -j | jq -r '.[] | "\(.class)\t\(.workspace.name)\tmapped=\(.mapped)\thidden=\(.hidden)\txwayland=\(.xwayland)"'
```

LM Studio는 이렇게 나왔다.

```
LM-Studio    1    mapped=true    hidden=false    xwayland=false
```

`xwayland=false` — Xwayland 폴백도 아니고 네이티브 Wayland로 붙었다. **Hyprland용 추가
설정은 아무것도 필요 없었다.** `--ozone-platform=wayland`를 주지 않아도 Electron이 알아서
잡는다. 로그 474줄에 Wayland/X11/ozone 관련 에러는 한 줄도 없었다.

같이 확인된 것: 엔진은 `llama.cpp-linux-x86_64-vulkan-avx2`가 자동 선택된다. Arc iGPU의
Vulkan 경로가 설정 없이 살아 있고, CUDA 엔진은 알아서 배제된다.

---

## 증상 2 — 심볼릭 링크를 없애자 vendor Python이 조용히 깨졌다

앱 홈을 `/mnt/ai`로 보내는 방법을 **심볼릭 링크 → 앱 고유 pointer 파일**로 바꾸자,
앱은 멀쩡히 뜨는데 로그에만 이런 줄이 생겼다.

```
[VendorLibIndexProvider] Vendor installation target
  /mnt/ai/lmstudio/extensions/backends/vendor/_amphibian/app-harmony-linux-x86@6
  is broken. Error: Python script failed with code 1
```

### 원인: 링크를 쓰는 동안 앱이 해석된 절대경로를 파일에 구웠다

`~/.lmstudio` → `/mnt/ai/lmstudio` 심볼릭 링크 상태로 첫 실행을 했다. 앱은 자기 데이터를
쓸 때 `realpath`로 해석된 경로 `/home/jh/.lmstudio/...`를 **설정 파일에 기록**했다.
링크를 없애자 그 기록들이 전부 존재하지 않는 경로를 가리켰다.

제일 비쌌던 것은 **Python venv**다. `pyvenv.cfg`는 설계상 prefix를 파일에 굽는다.

```
home = /home/jh/.lmstudio/extensions/backends/vendor/_amphibian/cpython3.11-linux-x86@3/bin
executable = /home/jh/.lmstudio/…/bin/python
```

경로가 바뀌면 venv는 그대로 죽는다.

### 헛다리 둘

| 가설 | 검증 | 결과 |
|---|---|---|
| 벤더 팩이 재배치 불가능하게 만들어졌다 | 래퍼 스크립트와 심볼릭 링크를 전부 읽음 | **반증.** `readlink -f "$0"` 기반에 전부 상대 링크. 완전히 재배치 가능하다 |
| 절대 심볼릭 링크가 홈을 가리킨다 | `find … -type l -lname '/home/jh/*'` | **반증.** 0개 |

두 번째로 시간을 더 쓴 것은 **호스트 셸에서 그 `python`을 직접 돌려 본 것**이다.

```
bad interpreter: /usr/bin/bash: no such file or directory
```

고장의 증거처럼 보이지만 아니다. 그건 913바이트 셸 스크립트이고 shebang이 `/usr/bin/bash`라,
**bwrap FHS 샌드박스 안에서만** 유효하다. 테스트 방법이 틀렸던 것이다.

---

## 증상 3 — 진단하려고 띄운 인스턴스가 홈에 2.5 GB를 다시 만들었다

`XDG_CACHE_HOME`/`XDG_CONFIG_HOME` 리다이렉트가 잘 되는지 검증하던 중, 홈에 캐시와 설정이
되살아났다. 리다이렉트가 새는 것으로 보였지만 아니었다. **조사하다가 래퍼를 안 거치고 띄운
두 번째 인스턴스**가 범인이었다.

프로세스마다 환경을 직접 물어보면 즉시 갈린다.

```sh
for pid in $(pgrep -f '[l]m-studio'); do
  echo "--- $pid"; tr '\0' '\n' < /proc/$pid/environ | grep -E '^XDG_(CACHE|CONFIG)_HOME'
done
```

```
--- 16228   XDG_CONFIG_HOME=/mnt/ai/config    ← 래퍼로 띄운 것
--- 16669   XDG_CONFIG_HOME=/home/jh/.config  ← 범인
```

`pgrep`/`pkill`에 `-f`를 줄 때 패턴을 `'[l]m-studio'`로 쓰는 이유도 여기서 배웠다.
`pkill -f "lm-studio"`는 **자기 명령줄까지 매칭해서 자기 셸을 죽인다.**

---

## 고침

앱을 멈추고, 구워진 옛 경로를 가진 파일 8개를 치환했다.

```sh
grep -rl '/home/jh/\.lmstudio' /mnt/ai/lmstudio          # 대상 찾기 (바이너리 포함)
sed -i 's|/home/jh/\.lmstudio|/mnt/ai/lmstudio|g' <파일들>
python3 -c "import json,sys; json.load(open(sys.argv[1]))" <각 json>   # 치환 후 파싱 검증
```

| 파일 | 구워져 있던 것 |
|---|---|
| `settings.json` | `downloadsFolder` |
| `.internal/internal-engine-index.json` | `engineLibPath`, `libLmStudioPath`, `dirPath` |
| `.internal/ui-state/global.json` | `projectPath` |
| `.internal/single-downloads-info.json` | temp-downloads `rootDir` |
| `.internal/download-jobs-info.json` | temp-downloads `rootDir` |
| `.internal/gguf-metadata-cache.json` | 모델 경로 |
| `pyvenv.cfg` | venv `home`, `executable` ← **증상 2의 범인** |
| `lib/python3.11/site-packages/sitecustomize.py` | `addsitedir()` |

결과: `is broken` 2건 → 0건, Vulkan 엔진 정상 재선택, 홈에 남은 것은 pointer 파일(16 B)과
런처(2 KB)뿐.

재발 방지는 `~/.local/bin/lm-studio` 런처가 맡는다. `XDG_*` 두 개를 export 하고, pointer를
매 실행 다시 쓰고, **`/mnt/ai`가 안 붙어 있으면 실행을 거부한다**(`nofail` 디스크라 없을 수
있고, 없는 채로 띄우면 앱이 조용히 홈에 다시 만든다).

---

## 다음에 빨리 잡는 법

1. **"안 켜진다"는 창 유무부터 컴포지터에 묻는다.** `hyprctl clients`. 콜드 스타트는 분
   단위일 수 있으니, 죽었다고 판단하기 전에 로그가 흐르고 있는지 본다.
2. **경로를 옮긴 뒤 앱이 이상하면 구워진 절대경로를 의심한다.** 한 줄로 전수조사된다.
   ```sh
   grep -rl '<옛 경로>' <앱 데이터 디렉터리>
   ```
   `.json`으로 한정하지 말 것 — `pyvenv.cfg`처럼 확장자가 다른 것이 진짜 범인이었다.
3. **앱 데이터를 옮길 때 심볼릭 링크를 쓰지 않는다.** 앱이 경로 설정을 제공하면 그것을
   쓴다. 링크는 앱이 `realpath`를 기록하는 순간 새는 추상화가 된다.
4. **누가 어디에 쓰는지는 `/proc/<pid>/environ`이 답한다.** 리다이렉트가 새는 것처럼
   보이면 먼저 프로세스 목록과 각자의 환경변수를 본다. 대개 범인은 다른 인스턴스다.
5. **샌드박스 안 스크립트를 호스트에서 돌리지 않는다.** `bad interpreter: /usr/bin/bash`는
   고장이 아니라 위치 착오다. 굳이 돌려 보려면 `APPIMAGE_DEBUG_EXEC`를 쓴다.
6. `pkill -f`는 패턴을 `'[l]m-studio'` 꼴로 쓴다. 안 그러면 자기 자신을 죽인다.

---

## 남은 것

- [ ] 런처(`~/.local/bin/lm-studio`)와 pointer 파일은 **선언적으로 관리되지 않는다.**
      의도된 상태다 — 이 디스크는 시험용이고 `/mnt/ai`만 `hosts/nixos/evo-t1/default.nix`가
      선언한다. 구성을 굳히기로 하면 `writeShellScriptBin`이나 home-manager의 `home.file`로
      옮길 것. 그 전까지는 클린 설치 후 이 문서를 보고 손으로 재현해야 한다.
- [x] 치환 전 원본 8개는 백업했고, JSON은 치환 후 파싱 검증까지 했다.
- [x] Arc iGPU의 Vulkan 추론 경로는 추가 설정 없이 동작한다. 실측까지 끝났다 — 생성 기준
      4 B에서 11.3배, 27 B에서 6.2배이고 `intel_gpu_top`으로 Render/3D 67~70% 점유를
      확인했다. 숫자와 그 해석상의 함정은 [로컬 추론](../local-inference.md)에 있다.
