# 터미널 취미 패키지

일을 하지 않는 것들. 선언은 `modules/shared/rice-toys.nix`에 따로 있고,
`packages.nix`가 마지막 줄에서 그것을 이어 붙인다.

---

## 왜 파일을 갈랐나

`packages.nix`는 "무슨 도구가 왜 필요한가"를 적는 자리다. `cbonsai`가 그 사이에
끼면 두 가지가 동시에 나빠진다 — 목록을 읽을 때 일하는 것과 노는 것을 매번 눈으로
갈라야 하고, 나중에 장난감을 통째로 빼고 싶을 때 흩어진 줄을 찾아다녀야 한다.

파일을 가르면 둘 다 없어진다. **빼려면 `packages.nix`의 import 한 줄을 지우면
된다.**

같은 프로필로 들어가는 것은 그대로다. 즉 **일하는 도구와 이름이 부딪히면 빌드가
깨진다** — 이건 함정이 아니라 안전망이다. `sl`과 `tt`처럼 짧은 이름은 선언 파일
주석에 "이 프로필에서 이 이름을 주장하는 게 이것뿐"이라고 근거를 적어 뒀다.

---

## 색은 여기 없다

`wallust`·`gowall`·`swww` 같은 것은 일부러 뺐다. 월페이퍼 → 팔레트는 이미 주인이
있다.

| 플랫폼 | 누가 |
|---|---|
| macOS | `pywal16` (`modules/darwin/rice/default.nix`) |
| NixOS | `matugen` + DMS (`modules/nixos/dms`, `modules/nixos/niri`) |

색 생성기가 둘이 되면 "색이 이상한데 어느 쪽이 정본이지"를 매번 다시 따져야 한다.
그 값이 도구 하나를 더 얻는 것보다 비싸다.

---

## 무엇이 있나

### 디지털 레인

| 도구 | 한 줄 |
|---|---|
| `cmatrix` | 원조. 다들 아는 그 화면 |
| `neo` | 실제 영화 글리프 + 24bit 컬러 |

```sh
cmatrix -ab -C cyan       # -a 비동기 스크롤, -b 굵게, -C 색
neo -c green --colormode 256
neo --charset=matrix -D   # 원작 글리프, 화면 흐리게
```

### 애니메이션

```sh
cbonsai -l -L 40 -M 3     # -l 라이브(계속 자란다), -L 길이, -M 여백
cbonsai -p -s 12          # -p 한 번 그리고 끝, -s 씨앗 고정 → 같은 나무 재현
pipes-rs -p 5 -f 60       # -p 파이프 수, -f 프레임레이트
asciiquarium
lavat -c red -R 6         # -R 방울 크기
bb                        # AA-lib 데모. 그냥 보면 된다
```

`sl`은 설명이 필요 없다. `ls`를 잘못 치면 기관차가 지나간다.

### 바빠 보이기

```sh
genact                          # 끝없는 그럴싸한 로그
genact -m cargo,docker_build    # 모듈을 골라서
genact --list-modules

hollywood                       # 화면을 쪼개 전부 채운다
```

`hollywood`는 Linux 에서만 설치된다. nixpkgs 가 `atop`을 PATH 에 넣어 감싸는데,
`atop`은 systemd 에 의존해 darwin 에서 빌드되지 않는다. tmux 는 함께 딸려 온다.

### 셸 시작 화면

unixporn 스크린샷의 왼쪽 위에 있는 그것.

```sh
colorscript random        # dwt1-shell-color-scripts
colorscript -l            # 목록
colorscript -e crunchbang

krabby random             # 포켓몬 스프라이트
krabby name pikachu --shiny
krabby random 1-3         # 1~3세대에서
```

**`.zshrc`에 무조건 물려도 되는 것은 `krabby`뿐이다.** 이 기계에서 재 보면
차이가 20배가 넘는다.

```
krabby random        5.0 ms ± 0.4 ms
colorscript random   118.1 ms ± 84.1 ms      (23.6배 느림)
```

`colorscript`가 느린 이유는 언어가 아니라 구조다 — 호출마다 셸 스크립트를
새로 포크한다. 118ms는 새 터미널을 열 때마다 체감되는 크기라, 이쪽은 셸 시작이
아니라 명령으로 두는 편이 낫다.

`terminaltexteffects`는 성격이 다르다 — 자기 그림이 없고, **stdin으로 들어온
아무 텍스트에나 효과를 입힌다.**

```sh
tte --help                       # 효과 목록
fastfetch | tte slide
cat README.md | tte beams
figlet "hello" | tte rain
```

### 텍스트 장식

```sh
figlet -f slant "nixos" | lolcat
toilet -f mono12 -F metal "rice"
fortune | cowsay | lolcat
fortune | charasay -f random     # 컬러 cowsay 후계
echo hi | boxes -d stone
```

### 오디오

```sh
cava                      # 설정은 ~/.config/cava/config
```

파이프와이어 환경에서는 대개 그냥 잡힌다. 안 잡히면 설정의 `[input] method`를
`pipewire` 또는 `pulse`로 명시한다.

### fetch

`fastfetch`와 `onefetch`가 `packages.nix`에 있고 그쪽이 기본이다. 여기 있는 것은
fastfetch가 안 하는 자리를 본다.

```sh
cpufetch                  # CPU 코어 토폴로지를 그림으로
ipfetch                   # 네트워크 쪽
macchina                  # 테마 가능한 패널 미학
hyfetch                   # pride flag 팔레트
nerdfetch                 # nerdfont 글리프, POSIX sh
```

### 시계

```sh
peaclock                  # 설정 가능한 시계/타이머/스톱워치
clock-rs
```

원조인 `tty-clock`은 일부러 뺐다 — nixpkgs가 `aarch64-darwin`에서 broken으로
표시했고, 이 파일은 darwin 빌드와 공유된다.

### 이미지 → 터미널

`chafa`(packages.nix)가 제일 낫고 기본이다. 여기 둘은 중복이 아니다.

```sh
ascii-image-converter img.png -C     # 진짜 ASCII 문자로 (chafa는 블록 글리프)
ascii-image-converter img.png -b     # 배경색까지
timg video.mp4                       # 정지 이미지가 아니라 재생을 한다
timg -g 80x40 anim.gif
```

### 타이핑

```sh
ttyper                    # rust, 제일 예쁘다
ttyper -w 50 -l english1000
typioca
tt -n 25                  # 최소한이고 스크립트로 다루기 좋다
```

### 게임

`vitetris` `nsnake` `nudoku` `ninvaders` `moon-buggy` `nethack`.

---

## 녹화 — 이 파일에서 유일하게 실용적인 묶음

rice를 남에게 보여주는 방법이자, `docs/`에 터미널 데모를 넣는 방법이다.

**`vhs`가 여기서 값어치가 크다.** 녹화가 스크립트라서 재현된다 — 마음에 안 들면
연기를 다시 하는 게 아니라 파일을 고치고 다시 돌린다.

```sh
cat > demo.tape <<'EOF'
Output demo.gif
Set FontSize 16
Set Width 1000
Set Height 600
Type "cbonsai -l -M 3"
Enter
Sleep 8s
Ctrl+C
EOF

vhs demo.tape
```

```sh
asciinema rec demo.cast   # 실제 세션을 녹화 (재현은 안 된다)
asciinema play demo.cast
termsvg export demo.cast -o demo.svg   # GIF 대신 애니메이션 SVG — 텍스트가 선명하다
```

GIF와 SVG의 갈림길: GitHub README에 붙일 거면 `vhs`의 GIF, 문서 사이트라 파일
크기와 글자 선명도가 중요하면 `termsvg`의 SVG.

---

## 함정

**이름이 짧은 것들은 프로필에서 이름을 다툰다.** `sl`·`tt`·`bb`·`neo`가 그렇다.
지금은 아무것도 부딪히지 않지만, 나중에 뭔가 추가하다 빌드가
`collision between ...`으로 깨지면 여기부터 의심할 것.

**셸 시작에 무거운 걸 물리면 티가 난다.** 파이썬으로 된 스프라이트/컬러스크립트는
한 번에 수십~수백 밀리초를 쓴다. `krabby`(rust)나 `colorscript`(셸)로 고르고,
`hyperfine`(packages.nix에 있다)으로 재 보면 된다.

```sh
hyperfine 'krabby random' 'colorscript random'
```

**`cava`가 조용하면 입력 방법 문제다.** 화면은 뜨는데 막대가 안 움직이는 게
그 증상이다. `~/.config/cava/config`의 `[input] method`를 명시한다.

---

## 안 넣은 것과 이유

- **`wallust` / `gowall` / `swww` / `mpvpaper`** — 위 "색은 여기 없다" 참조.
- **`starship` / `oh-my-posh`** — 프롬프트는 `zsh-powerlevel10k`가 맡고 있다.
- **`glances` / `gtop` / `zenith`** — `btop`·`bottom`·`htop`·`procs`와 겹친다.
- **`pipes`** — `pipes-rs`와 자리가 같다.
- **`tty-clock` / `jp2a`** — nixpkgs가 `aarch64-darwin`에서 broken으로 표시했고
  이 파일은 darwin과 공유된다. 각각 `peaclock`·`ascii-image-converter`가 대신한다.
- **`rain`** — **이름 함정.** nixpkgs의 `rain`은 비 애니메이션이 아니라 AWS
  CloudFormation 워크플로 도구다. 디지털 레인은 `neo`/`cmatrix`다.
- **`nvtop`** — 이 무리에 어울리지만 이미 깔려 있다. `modules/nixos/amd.nix`와
  `modules/nixos/intel.nix`가 각각 `nvtopPackages.amd`/`.intel`을 벤더에 맞춰
  넣는다. 여기서 또 넣으려면 최상위 attribute가 없어 `nvtopPackages.full`을
  골라야 하는데, 그건 NVIDIA 백엔드를 켜면서 unfree인 `cuda_nvml_dev`를
  끌어온다 — 이 레포의 어떤 호스트에도 없는 하드웨어를 위해서.
- **nixpkgs에 없음** — `no-more-secrets`, `lolcrab`, `shell-color-scripts`,
  `2048-in-terminal`, `gotta-go-fast`, `projectm`, `cli-visualizer`, `termgraph`.

---

## 관련 문서

- [`README.md`](README.md) — 이 디렉토리(도구 안내서)의 인덱스
- [`../02-this-repo.md`](../02-this-repo.md) — 선언이 어느 파일로 흘러가는지
