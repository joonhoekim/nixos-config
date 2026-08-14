# 로컬 추론 — evo-t1의 LM Studio와 `/mnt/ai`

evo-t1에서 로컬 모델을 돌리는 구성 전체. **디스크를 세우는 것부터 iGPU 추론 속도를
재는 것까지** 한 번에 적는다.

이 문서만 유일하게 선언적이지 않은 부분을 서술한다. `/mnt/ai` 파일시스템은
`hosts/nixos/evo-t1/default.nix`가 선언하지만, **그 위의 LM Studio 구성은 전부 명령형**이다.
시험 단계라 일부러 그렇게 뒀고, 클린 설치 후에는 이 문서를 보고 손으로 재현해야 한다.
AppImage 자체의 동작 원리는 [AppImage와 NixOS](appimage-on-nixos.md)에 따로 있다.

측정값은 전부 2026-08-15 evo-t1 실측이다.

---

## 무엇이 어디에 있나

| | |
|---|---|
| 하드웨어 | Core Ultra 9 285H (16코어, P6+E8+LPE2), Arc Pro 130T/140T iGPU, 62 GiB RAM |
| 디스크 | `/dev/nvme0n1p1` ext4 `ai` → `/mnt/ai` (469 G) |
| 앱 | `~/Downloads/LM-Studio-0.4.21-2-x64.AppImage` |
| 런처 | `~/.local/bin/lm-studio` |
| CLI | `~/.local/bin/lms` → `/mnt/ai/lmstudio/bin/lms` |
| 추론 엔진 | `llama.cpp-linux-x86_64-vulkan-avx2@2.28.2` (자동 선택) |

`/mnt/ai` 아래 구조:

```
/mnt/ai/cache/appimage-run/<sha256>/   AppImage 추출 캐시   746 M
/mnt/ai/config/LM Studio/              Electron userData    2.5 M
/mnt/ai/lmstudio/                      앱 홈: 모델·런타임·설정
/mnt/ai/lmstudio/models/               GGUF                 20.6 G
```

---

## 1. 디스크

`nvme0n1`은 Windows 시절 exFAT 그대로 놀고 있던 512 G NVMe다. GPT 단일 파티션 ext4로
다시 세웠다. 선택 근거(왜 btrfs가 아닌지, `-m 0`과 `noatime`, label 주소지정)는
`hosts/nixos/evo-t1/default.nix`의 `── nvme0n1: scratch space` 절에 있다.

```sh
sudo wipefs -a /dev/nvme0n1p1 /dev/nvme0n1p2 /dev/nvme0n1
printf 'g\nn\n1\n\n\nw\n' | sudo fdisk /dev/nvme0n1
sudo mkfs.ext4 -L ai -m 0 /dev/nvme0n1p1
sudo mkdir -p /mnt/ai && sudo chown $USER /mnt/ai
```

마운트는 선언이 맡는다. 디스크가 빠져도 부팅을 막지 않는다(`nofail`).

```nix
fileSystems."/mnt/ai" = {
  label = "ai";
  fsType = "ext4";
  options = [ "noatime" "nofail" ];
};
```

쓰기 속도는 3.1 GB/s (256 MiB, O_DIRECT).

---

## 2. 앱 실행 — `appimage-run`

NixOS에는 `/lib64/ld-linux-x86-64.so.2`가 없어 AppImage가 직접 실행되지 않는다.
`modules/nixos/packages.nix`의 `appimage-run`을 통해야 한다. 자세한 이유는
[별도 문서](appimage-on-nixos.md).

**Hyprland용 추가 설정은 필요 없다.** Electron이 알아서 네이티브 Wayland로 붙는다
(`hyprctl clients`에서 `xwayland: false` 확인). `--ozone-platform=wayland`를 줄 필요가 없다.

첫 실행은 느리다 — 746 M 압축 해제 + 1.8 G 런타임 다운로드가 창 뜨기 전에 끝나야 한다.
캐시가 찬 뒤로는 5초 안에 뜬다. **멈춘 게 아니라 느린 것이니 Ctrl+C 하지 말 것.**

---

## 3. 모든 것을 `/mnt/ai`에 두기

앱이 쓰는 곳이 셋이고 **각각 제어 수단이 다르다.** 이게 이 구성의 핵심이다.

| 대상 | 크기 | 수단 |
|---|---|---|
| AppImage 추출 캐시 | 746 M | `XDG_CACHE_HOME` |
| Electron userData | 2.5 M | `XDG_CONFIG_HOME` |
| 앱 홈(모델·런타임) | 20 G+ | `~/.lmstudio-home-pointer` — 대상 경로 한 줄짜리 텍스트 파일 |

`~/.local/bin/lm-studio`가 셋을 처리한다. 핵심만:

```sh
export XDG_CACHE_HOME=/mnt/ai/cache
export XDG_CONFIG_HOME=/mnt/ai/config
printf '%s' /mnt/ai/lmstudio > "$HOME/.lmstudio-home-pointer"
exec appimage-run "$APPIMAGE" "$@"
```

런처는 시작 전에 `mountpoint -q /mnt/ai`로 확인하고 **안 붙어 있으면 실행을 거부한다.**
`nofail` 디스크라 없을 수 있고, 없는 채로 띄우면 앱이 조용히 홈에 2.5 G를 다시 만든다.

결과적으로 홈에 남는 것은 텍스트 파일 둘뿐이다 — pointer(16 B)와 런처(2 KB).

> **심볼릭 링크로 하지 말 것.** `~/.lmstudio`를 링크로 옮기면 앱이 `realpath`로 해석한
> 절대경로를 설정 파일에 구워 버리고, 나중에 링크를 걷는 순간 전부 어긋난다. Python venv의
> `pyvenv.cfg`가 특히 그렇다. 전말은 [사후 기록](postmortems/2026-08-15-lm-studio-appimage-paths.md).

---

## 4. `lms` CLI — PATH에 안 걸리는 이유

앱에서 CLI를 설치하면 바이너리는 `/mnt/ai/lmstudio/bin/lms`(109 M)에 제대로 놓인다.
그런데 **PATH에는 안 걸린다.** LM Studio는 셸 rc에 PATH 한 줄을 덧붙이는 방식인데,

```
~/.zshrc -> /nix/store/…-home-manager-files/.zshrc
```

home-manager가 관리하는 스토어 심볼릭 링크라 읽기 전용이다. 덧붙이기가 조용히 실패한다.
`~/.local/bin`은 이미 PATH에 있으므로 거기로 링크한다.

```sh
ln -sfn /mnt/ai/lmstudio/bin/lms ~/.local/bin/lms
```

`/mnt/ai`가 빠지면 이 링크는 끊어져 `command not found`가 된다. 정상 동작이다.

---

## 5. 모델 다운로드 — HF 프록시를 끈다

기본값 `useHFProxy: true`는 다운로드를 `search.lmstudio.ai/v1/hf-proxy/...`로 우회시킨다.
HF가 막힌 지역을 위한 것이고, **여기서는 순수 손해다.**

| 경로 | 실측 |
|---|---|
| LM Studio 기본 (HF 프록시) | **~350 KB/s** (103 K ~ 614 K 사이로 요동) |
| huggingface.co 직접 | **39 MB/s** |

**약 110배.** 16.8 G짜리 모델이 2시간 대 7분의 차이가 된다. 앱 설정에서 끄거나,
앱을 멈추고 `/mnt/ai/lmstudio/settings.json`의 `useHFProxy`를 `false`로 바꾼다
(앱이 켜져 있으면 종료할 때 덮어쓴다).

### 받다 만 것은 이어받을 수 있다

`.part` 파일은 구멍 없는 연속 파일이고(`du` 실제 블록 vs 논리 크기로 확인), 프록시 URL에서
`search.lmstudio.ai/v1/hf-proxy/` 부분만 `huggingface.co/`로 바꾸면 같은 파일이다.
sha256은 앱이 `.internal/single-downloads-info.json`에 기록해 둔 것을 쓴다.

```sh
curl -sS -L -C - --retry 5 -o "$part" \
  "https://huggingface.co/$repo/resolve/main/$file"
sha256sum "$part"        # 기록된 값과 대조
mv "$part" "$dest"       # downloading_X.gguf.part -> X.gguf
```

`HTTP 206`으로 붙고, 프록시로 받은 앞부분과 직접 받은 뒷부분이 합쳐져 해시가 일치하면
이어받기가 온전했다는 뜻이다. 10.3 G를 버리지 않고 살렸다.

> 손으로 넣은 파일을 앱이 다시 받으려 들면, 앱의 다운로드 기록이 아직 "진행 중"이기
> 때문이다. `.internal/download-jobs-info.json`의 `active` job까지 지워야 멈춘다.
> 자세한 것은 사후 기록에.

---

## 6. 성능 — iGPU가 실제로 일하는가

`lms load --gpu max|off`로 같은 모델을 두 번 재면 iGPU 기여분이 그대로 나온다.

| 모델 | GPU | 로드 | 생성 (tok/s) | TTFT | 프리필 (tok/s) |
|---|---|---|---|---|---|
| nemotron-3-nano-4b (4 B, `nemotron_h`) | max | 1.6 s | **14.74** | 0.54 s | **143.5** |
| nemotron-3-nano-4b | off | 3.8 s | 1.31 | 2.16 s | 3.2 |
| qwen3.8-27b (27 B, `qwen35`, VLM) | max | 10.4 s | **2.66** | 7.84 s | (측정 실패) |
| qwen3.8-27b | off | 14.2 s | 0.43 | 35.92 s | 9.2 |

생성 기준 **4B가 11.3배, 27B가 6.2배**. Vulkan 백엔드는 설정 없이 동작한다.

### GPU가 도는 증거

`intel_gpu_top`으로 생성 중에 직접 확인했다. 추론은 Vulkan 컴퓨트 셰이더라 `Compute`가
아니라 **Render/3D 엔진**에 잡힌다.

```
GPU MHz   GPU W   RCS busy%   llama-server RCS%
   2080    9.69       72.5      67.1%
   2017    9.81       73.1      67.1%
   2146    9.96       76.0      69.9%
```

2.0~2.1 GHz, 9.7 W, `llama-server`가 Render/3D를 67~70% 점유. 확실히 일하고 있다.

### CPU 쪽 숫자는 곧이곧대로 읽지 말 것

위 배수는 **"LM Studio 기본 GPU 설정 대 LM Studio 기본 CPU 설정"**이지, "이 iGPU 대 이
CPU의 최대 성능"이 아니다. CPU 경로가 두 가지로 불리하다.

- `llama-server`가 `--threads 6`으로 뜬다(16코어 중 6, P코어 수와 일치). 실측 사용률은
  프리필 중 3.2코어, 생성 중 1.0코어 — 기계의 20% 이하만 쓴다.
- 더 이상한 것: **4 B의 CPU 프리필(3.2 tok/s)이 27 B의 CPU 프리필(9.2 tok/s)보다 느리다.**
  파라미터가 6배 적은 모델이 3배 느릴 수는 없다. `nemotron_h`는 Mamba 하이브리드고,
  llama.cpp의 CPU SSM 경로가 이 구조에서 특히 나쁜 것으로 보인다. 즉 4B의 11.3배에는
  **망가진 CPU 기준선이 섞여 있다.** 27B의 6.2배가 더 믿을 만한 숫자다.

### 재현

```sh
lms server start
lms load <model> --gpu max --context-length 4096 --identifier bench -y
curl -s http://127.0.0.1:1234/api/v0/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"bench","messages":[{"role":"user","content":"…"}],
       "temperature":0,"max_tokens":200,"stream":false}' \
  | jq .stats     # tokens_per_second, time_to_first_token, generation_time
lms unload --all
```

프리필 속도는 긴 프롬프트를 넣고 `prompt_tokens / time_to_first_token`으로 계산한다.
GPU 점유는 `sudo intel_gpu_top -J -s 1500`에서 `clients[].name`이 `llama-server`인 항목의
`Render/3D`를 본다.

---

## 알아 둘 것

- **모델 크기 상한은 VRAM이 아니라 RAM이다.** Arc iGPU는 시스템 메모리를 공유한다.
  62 GiB에서 27 B Q4_K_M(17.7 G)은 여유롭다.
- 27 B는 VLM이다. `mmproj-Qwen3.8-27B-BF16.gguf`(931 M)가 비전 인코더고, 같은 디렉터리에
  있어야 이미지 입력이 된다.
- 첫 실행 로그의 `Failed to survey hardware with engine '…nvidia-cuda…'`는 무해하다.
  NVIDIA가 없으니 당연하고, 그 엔진은 이미 미선택이다.
- `Fontconfig warning` 수십 줄은 NixOS의 `/etc/fonts/conf.d/48-guessfamily.conf`가 내는
  것으로 LM Studio와 무관하다.

## 미해결

- [ ] 27 B의 프리필 속도를 못 쟀다. 1682 토큰 프롬프트에 `max_tokens: 16`으로 요청하면
      `--gpu max`에서만 `HTTP 400 Bad Request`가 난다(`--gpu off`에서는 9.2 tok/s로 정상
      측정됨). 같은 모델·같은 프롬프트인데 오프로드 설정에 따라 갈리므로 요청 형식 문제는
      아니다. 다시 볼 때는 `lms log`를 켜 놓고 서버가 뭘 거부하는지 볼 것.
- [ ] CPU 스레드를 16으로 올렸을 때의 값을 안 쟀다. 위 배수를 "하드웨어 대 하드웨어"로
      말하려면 그 숫자가 있어야 한다.
- [ ] 런처와 pointer가 선언적으로 관리되지 않는다. 굳히려면 `writeShellScriptBin` 또는
      home-manager `home.file`.
