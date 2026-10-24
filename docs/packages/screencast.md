# 화면 녹화로 데모 영상 만들기

창 관리자나 앱이 움직이는 모습을 남에게 보일 영상으로 만드는 흐름이다. 녹화하고,
쓸 구간을 정하고, 자막과 앞뒤 카드를 얹어 mp4(와 gif)로 내보낸다. 마지막 단계는
[`apps/screencast`](../../apps/screencast)가 한다.

쓰는 도구는 이미 선언돼 있다: `ffmpeg`(자르기·자막·카드·이어 붙이기), `gifski`(gif),
`imagemagick`(정지 화면 손질). 모두 [`modules/shared/packages.nix`](../../modules/shared/packages.nix)에
있다. 아래 "더 높은 품질" 절의 도구는 일부러 넣지 않았다. 필요할 때 그 절의
방법대로 더한다.

## 1. 녹화 (macOS)

```sh
screencapture -x -v -V 22 -D 2 raw.mov   # 22초, 두 번째 디스플레이, 소리 없이
```

- `-D`는 디스플레이 번호다. 1이 메뉴 막대가 있는 주 디스플레이다. 내장 디스플레이만
  찍으려면 외부 모니터가 주 디스플레이일 때 2다.
- `-v`는 ScreenCaptureKit으로 찍는다. **정지 스크린샷(`screencapture`)에는 안 나오는
  창이 영상에는 나온다.** CAContext를 직접 붙인 오버레이(rift의 오버뷰, 이동
  슬라이드)가 그렇다. 확인용 스냅샷이 비어 보여도 영상은 멀쩡할 수 있다.
- 녹화를 시작하면 메뉴 막대에 녹화 표시가 뜨면서 앱 활성화가 한 번 바뀐다. 포커스가
  바뀌면 닫히는 화면(rift 오버뷰)은 **녹화를 먼저 시작하고** 연다.
- 레티나에서는 2배 해상도로 찍혀서 22초에 175MB쯤 된다. 원본은 scratch에 두고
  레포에 넣지 않는다.
- 녹화하는 터미널에 화면 기록 권한이 있어야 한다(시스템 설정 > 개인정보 보호 및
  보안 > 화면 및 시스템 오디오 녹음).

NixOS(Hyprland)에서는 `wf-recorder`(nixpkgs, Linux 전용)나 OBS를 쓴다. 이 레포에는
아직 선언되지 않았다.

### 화면을 깨끗하게

- **마우스 커서:** 영상에 찍힌다. 화면 아래 끝에 두면 숨겨 둔 Dock이 올라오니,
  오른쪽 가장자리 가운데쯤으로 옮겨 둔다. 이벤트 없이 커서만 옮기려면
  `CGWarpMouseCursorPosition`을 부르는 몇 줄짜리 Swift면 된다. 이벤트가 없으니
  focus-follows-mouse도 깨지 않는다.
- **찍는 디스플레이에 남의 창이 없게:** 최소화하거나 다른 워크스페이스로 옮긴다.
- **크기 조정 표시:** Ghostty는 창 크기가 바뀔 때 "179 x 49" 같은 크기 표시를 띄운다.
  데모용 창은 `--resize-overlay=never`로 연다.
- **창 내용:** 데모용 창에는 무엇인지 알아볼 큰 글씨를 띄워 두면 좋다. 예: `figlet`으로
  창 이름을 그리고 `trap ... WINCH`로 크기가 바뀔 때마다 다시 그린다.

## 2. 연출은 스크립트로 몬다

키를 합성하지 말고 **같은 액션을 CLI로 부른다**(`rift-grid-cli execute layout grid-cell right`
같은 식). [`apps/demo`](../../apps/demo) 머리말과 같은 이유다. 합성 키 이벤트는 접근성
권한이 필요하고, Alt 같은 수정 키가 HID 상태에 눌린 채 남는 사고가 난다.

```sh
screencapture -x -v -V 22 -D 2 raw.mov &
sleep 2                                   # 녹화가 자리 잡을 시간
at() { sleep "$1"; shift; "$@"; }
at 1.2 rift-grid-cli execute layout grid-focus right
at 1.2 rift-grid-cli execute layout grid-cell down
...
wait
```

- 명령 간격을 적어 두면 그대로 자막 시각이 된다. 이 경우 녹화 시작 지연과 앞에서
  잘라 낸 길이를 빼야 하는데, 둘이 비슷해서 0.1~0.3초 안에서 맞았다.
- 시각을 모르면 장면 전환을 뽑아 맞춘다. 어두운 화면에서는 문턱을 낮춰야 한다.
  ```sh
  ffmpeg -i out.mp4 -vf "select='gt(scene,0.04)',showinfo" -f null - 2>&1 | grep -o 'pts_time:[0-9.]*'
  ```
- 찍는 동안 사람이 건드리면 망한다. 시작 전에 사람이 입력 중인지 본다
  (`ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $NF/1e9; exit}'`, 초 단위).
  알릴 때는 `nautice say -a -q "녹화한다, 30초 동안 건드리지 마"`를 쓴다.
- 결과는 프레임을 타일로 모아 한눈에 검수한다.
  ```sh
  ffmpeg -i raw.mov -vf "fps=2,scale=320:-1,tile=8x6" -frames:v 1 sheet.png
  ```
  30fps로 촘촘히 뽑으면 한두 프레임짜리 글리치도 보인다.

## 3. 다듬기 — `apps/screencast`

```sh
apps/screencast --example > demo.cast   # spec 틀
apps/screencast demo.cast --gif         # demo.mp4, demo.gif
```

spec 형식은 스크립트 머리말에 있다. 하는 일은 다음과 같다.

1. **본편:** `trim` 구간을 자르고 `width`로 줄인다. 2배 해상도 원본을 1배로 줄이면
   용량이 크게 준다. `hold`만큼 첫 장면을 멈춰 붙인다. `caption`마다 `drawtext`로
   아래쪽 반투명 상자 자막을 얹는다(0.15초 페이드).
2. **카드:** `backdrop` 이미지(없으면 본편의 첫/끝 장면)를 흐리고 어둡게 한 위에 제목과
   한두 줄을 쓴다. 배경 화면이 가장 보기 좋았다. 첫 장면이 어두운 창이면 카드가 거의
   검정이 된다.
3. **잇기:** 카드와 본편을 0.5초 `xfade`로 이어 x264(crf 21, faststart)로 내보낸다.
   `--gif`면 20fps, 너비 960으로 `gifski`에 넘긴다.

함정:
- `drawtext`의 글은 파일(`textfile=`)로 넘긴다. 콜론, 따옴표, `⌥` 같은 글자를 필터
  문법에 맞게 이스케이프하는 것보다 확실하다.
- 키 기호(⌥⇧⌘)는 macOS의 SF(`/System/Library/Fonts/SFNS.ttf`)에 있다. 다른 글꼴에서는
  빈 칸으로 나올 수 있다.
- 첫 자막이 카드 크로스페이드 0.5초에 묻힌다. 그래서 `hold`가 있다.
- ffmpeg 9에서 긴 필터 그래프는 `-/filter_complex 파일`로 넘긴다. 예전의
  `-filter_complex_script`는 없어졌다.

## 4. GitHub에 올리기

README의 영상은 레포에 파일로 커밋하면 재생되지 않는다. 웹에서 이슈나 README 편집
화면에 끌어다 놓아야 `user-attachments` 주소가 생기고 인라인으로 재생된다. 무료
플랜의 영상 제한은 10MB다. 1512px, 60fps, 20~25초 데모가 3~4MB였으니 여유가 있다.
레포에 넣을 거라면 gif가 맞다(이미지도 10MB까지).

## 5. 더 높은 품질이 필요하면

지금 흐름의 한계: 자막 상자가 각지고 줄바꿈이 없다. 카드는 글자뿐이다. 커서
움직임과 확대 같은 연출이 없다. 어디를 올리고 싶은지에 따라 꺼낼 도구가 다르다.

| 올리고 싶은 것 | 도구 | 들이는 법 |
|---|---|---|
| 자막 모양(둥근 상자, 위치, 효과, 여러 줄) | ASS 자막. [Aegisub](https://aegisub.org)로 시각과 스타일을 편집하고 ffmpeg `subtitles=x.ass`(libass)로 굽는다 | `aegisub`는 nixpkgs에 있다(macOS·Linux). ffmpeg의 libass는 이미 있다 |
| 실제로 누른 키 표시 | KeyCastr | nixpkgs `keycastr`(macOS 전용). 다만 이 흐름은 키를 누르지 않고 CLI로 몰기 때문에, 사람이 직접 시연할 때만 쓸모 있다 |
| 내레이션 받아쓰기 자막 | whisper.cpp로 음성에서 `.srt`를 뽑아 `subtitles=`로 굽는다 | nixpkgs `whisper-cpp`(macOS·Linux) |
| 내레이션 목소리 | macOS `say -o narration.aiff "..."` → ffmpeg로 섞는다 | 이미 있다 |
| 커서 따라 확대, 부드러운 커서 | Screen Studio(유료, macOS) | 명령형 설치. 녹화 단계를 통째로 바꾼다 |
| 컷 편집, 타임라인 | Shotcut(가볍다), DaVinci Resolve(무료, 무겁다), Kdenlive(Linux) | nixpkgs `shotcut`(macOS·Linux), `kdePackages.kdenlive`(Linux). Resolve는 brew cask |
| 코드로 짠 모션 그래픽(카드, 다이어그램 애니메이션) | [Motion Canvas](https://motioncanvas.io)(TypeScript, MIT) 또는 Remotion(React, 개인 무료, 회사는 라이선스) | npm 프로젝트로 그때그때 쓴다(`npm init @motion-canvas@latest`). 선언할 것은 없다 |
| 녹화 자체(장면 전환, 여러 소스) | OBS Studio | nixpkgs `obs-studio`(Linux). macOS는 brew cask `obs` |

nix로 들일 것은 `modules/shared/packages.nix`(양쪽) 또는 플랫폼별 `packages.nix`에
주석 한 줄과 함께 더하고, 쓸 레시피가 생기면 이 문서에 적는다.
