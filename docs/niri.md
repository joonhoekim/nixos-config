# niri 세션

niri 는 스크롤링 타일링 Wayland 컴포지터다(창이 컬럼으로 오른쪽에 끝없이 쌓이는 띠). 이 저장소에서는
`modules/nixos/niri` 가 niri 를 hosts/nixos/common.nix 의 GNOME 세션 옆에 깔고, DankMaterialShell(DMS, Quickshell 기반
바·런처·컨트롤 센터·알림·잠금 화면)이 그 위에서 돈다. GNOME 은 셸 업데이트가 데스크톱을 깨뜨렸을 때의 대피로다.
로그인 화면과 기본 세션은 [nixos-common](nixos-common.md#로그인-화면greetd과-세션).

## 상류

전부 고정된 nixpkgs/home-manager 에서 온다 — flake 입력이 없다. 안내서 대부분은 sodiboo/niri-flake 를 쓰지만 nixpkgs
에 `programs.niri` 와 `programs.dms-shell` 이 있고, 그 flake 가 더하는 선언적 셸 설정은 이 모듈이 일부러 원하지 않는다
(아래 절).

## 설치는 선언적, 라이싱은 아니다

모듈은 세션을 설치·배선하고 설정은 소유하지 않는다. 사용자가 쥐는 파일:

- `~/.config/niri/config.kdl` — 핫 리로드, 깨진 편집은 에러만 찍고 직전 설정이 돈다
- `~/.config/DankMaterialShell/` — DMS 설정 GUI 가 쓴다
- `~/.config/ghostty/config`

HM 의 `wayland.windowManager.niri.settings` 를 안 쓰는 이유: config.kdl 이 읽기 전용 스토어 심링크가 되어 키바인드
하나에도 rebuild 가 들고, DMS(여러 설정 탭에서 config.kdl 에 `include` 를 덧붙인다)가 읽기 전용 대상에 조용히 실패한다.
home.file / xdg.configFile 도 같은 이유로 안 쓴다 — DMS 설정 GUI 는 원자적으로 써서(임시 파일 + rename,
Common/SettingsData.qml) 심링크를 첫 저장에 보통 파일로 바꾼다.

`rice/` 는 새 머신의 출발점이고 없을 때만 심는다(`[ -e ]` — 라이싱 도중 rebuild 가 저장 안 한 작업을 덮지 않는다. 판정
규칙은 [rice-seeding](rice-seeding.md)). 되받기는 `apps/rice/save`. DMS 의 settings.json 은 시드가 없다 — 21KB 의 GUI
상태이고, 룩은 `rice/profiles/*/dms.json` 이 담아 `apps/rice/switch` 가 DMS 의 첫 실행 기본값 위에 합친다.

- activation 은 HM 의 linkGeneration 뒤에 둔다. config.kdl 이 이전 세대의 HM 심링크로 남은 머신에서는 HM 이 그 링크를
  지운 뒤에 복사가 들어가야 한다.
- 모듈 함수로 쓴 건 `lib` 이 HM 것이어야 해서다(`lib.hm` 은 NixOS 모듈 스코프에 없다).
- config.kdl 의 탭 들여쓰기와 알파벳순 노드는 처음에 wayland.windowManager.niri 로 생성했던 모양이 남은 것이다.
- seedProfile 은 처음 심을 프로필일 뿐이고 첫 전환부터 apps/rice/switch 가 소유한다(옵션으로 두면 선언적이라는 뜻이 되어
  안 둔다). 프로필 조각(profile.kdl, rice/current)도 심어 새 머신이 일관된 룩으로 뜬다.

## 그 밖의 심기

- **ghostty** 는 `modules/shared/ghostty` 가 심는다. macOS 도 같은 파일을 쓰므로 니리(리눅스 전용) 밑에 두면 경로부터
  막힌다. 색은 matugen(벽지에서 팔레트를 뽑는 도구)이 `theme = dankcolors` 가 읽는 파일을 다시 쓴다
  (matugenTemplateGhostty). 이 레포는 터미널 색을 따로 선언하지 않는다.
- **fuzzel**(Wayland 런처): 형태(폰트/여백/줄높이)만 레포가 갖고, 색과 lines/radius 는 `apps/rice/fuzzel` 이
  dank-rice.ini 에 쓴다([rice-tools.md](rice-tools.md#fuzzel-색--appsricefuzzel)).
  - include 줄을 모듈이 붙이는 건 fuzzel 이 절대 경로만 받고(기본 섹션 전용이라 첫 [main] 앞) 홈 경로는 모듈이 알기 때문이다.
    rice-fuzzel 도 붙일 줄 알지만 그건 손으로 만든 설정용 안전망이고, 첫 로그인에 기본 테마(솔라라이즈드 라이트)로 안
    뜨려면 이 시점에 배선돼 있어야 한다.
  - include 가 먼저 읽히므로 fuzzel.ini 에 [colors] 를 두면 생성된 색을 덮는다.
  - dank-rice.ini 폴백(fuzzel-fallback.ini)은 무채색에 거의 불투명 — 셸이 죽었을 때 여는 런처라 그때 읽혀야 한다.
    덮어써지는 파일이라 apps/rice/save 로 안 되받는다.
  - lines 는 rice-fuzzel 이 화면 높이 80%(RICE_FUZZEL_RATIO)로 다시 계산한다. layer=overlay 로 바 위에 뜨고, 포커스를 잃으면
    닫힌다(실수로 열었을 때).
- **GTK**(gtk-settings.ini → gtk-3.0, gtk-4.0): HM `gtk` 가 아니라 시드다. DMS 가 같은 파일을 건드린다 —
  SettingsData.qml 의 updateGtkIconTheme 이 gtk-icon-theme-name 을 sed 로 쓰고, scripts/gtk.sh 는 gtk.css 를 갈아친다.
  HM 이 심링크로 잡으면 진 쪽이 다음 rebuild 를 "would be clobbered" 로 막는다. 그래서 쓰기 가능한 파일로 깔고 소유권은
  DMS 에 준다.
  - 니리에는 XSettings 를 방송할 데몬이 없어 GTK3 앱이 이 파일을 직접 읽고, 비면 라이트 테마다.
  - 색은 DMS 가 dank-colors.css 에 쓰고 설정 GUI 의 "Apply GTK colors" 가 gtk.css 에서 import 한다.
  - GNOME 세션에서는 gnome-settings-daemon 이 XSettings 로 방송하고 GTK 는 dconf(org/gnome/desktop/interface,
    modules/nixos/home-manager.nix)를 따라 이 파일은 사실상 안 읽힌다. GNOME 을 걷어내면 같이 지울 것은 dconf 블록이다.
  - 되받기는 apps/rice/save 가 gtk-3.0 을 정본으로 삼고 gtk-4.0 이 어긋나면 알린다.
- **gtk.enable 을 HM 에 두지 않는 이유**(modules/nixos/home-manager.nix): scripts/gtk.sh 가 ~/.config/gtk-4.0/gtk.css 에
  `sed -i` 로 HM 심링크를 실파일로 바꾸고, 심링크된 gtk-3.0/gtk.css 는 `rm` 하며, SettingsData.qml:1605 는 없으면
  gtk-{3,4}.0/settings.ini 를 만든다. 그러면 HM 이 관리하던 자리에 실파일이 생겨 그 뒤 모든 rebuild 가 실패한다
  (DMS 는 쓸 수 없는 settings.ini 는 건너뛰어(`[ ! -w ] && continue`) 링크가 먼저 있던 머신은 살아남으므로, 머신마다
  결과가 갈린다). 셸이 이미 niri·ghostty·fuzzel 의 팔레트를 소유하고 gtk-3.0/dank-colors.css 가 GTK 앱이 벽지를
  따라가게 하므로 GTK 를 DMS 에 넘기는 것이 일관된다. 테마(adwaita-icon-theme, gnome-themes-extra 의 Adwaita-dark)는 DMS
  가 가리킬 대상이 있게 Nix 로 깐다.
- **programs.niri** 는 displayManager.sessionPackages 에 niri 를 넣고 niri.service 를 싣고 xdg.portal.config.niri =
  gnome+gtk 를 선언한다(데스크톱별 이름공간). xwayland-satellite 는 $PATH 에 있으면 니리가 필요할 때 띄운다(없으면 X11
  클라이언트가 붙을 디스플레이가 없다). fuzzel 은 Mod+D 폴백 런처다.
- **dms.service** 는 `[Install] WantedBy=graphical-session.target` 을 싣지만 NixOS 는 패키지 유닛의 [Install] 을 무시하고
  `systemd.target` 이 가리키는 .wants 심링크만 쓴다. niri.service 를 가리켜 셸을 니리 세션에 가둔다(빌드된 시스템에서
  etc/systemd/user/niri.service.wants/dms.service 가 있고 graphical-session.target.wants 항목은 없음). 하이프랜드 쪽은
  [hyprland.md](hyprland.md#dms-를-이-세션에서도-띄우기-dmswantedby).

## config.kdl 의 판단

- **include 순서.** animations.kdl 은 optional include 이고, DMS 가 "DMS Include Configs" 헤더 밑에 include 를 이어
  붙이므로 그 위에 둔다. DMS 조각 include 가 없으면 테마가 포커스 링·보더·벽지 배경에 안 닿는다. dms/layout.kdl 은 뺐다
  (갭/보더 폭을 layout 블록이 소유한다; 쓰려면 그 값을 먼저 지운다).
- **`focus-workspace-previous`** 는 니리 기본 설정에 없는 액션이다. 니리는 모르는 액션이 있으면 설정 전체를 거부해
  로그인이 안 되므로 `niri msg action --help`·`niri validate` 로 확인했다(2026-08-06, 실기). 워크스페이스는 세로로 쌓여
  U 가 위, O 가 아래(I 를 위에서 감싸는 두 자리).
- **오버뷰 Mod+E**(하이프랜드는 DMS 오버뷰, rift-grid 는 미션 컨트롤; 니리 기본 Mod+O 는 여기서 워크스페이스 앞으로).
  repeat=false 는 니리 기본 설정을 따라 누르고 있을 때 토글이 연달아 터지는 걸 막는다. Mod+H 는 치트시트(rift-grid 엔
  대응물 없음, [keymap.md](keymap.md)).
- **Mod+Ctrl+E consume-or-expel-window-right**: 니리는 액션 하나로 있다. -right 인 것은 하이프랜드 consume 이 오른쪽에서만
  끌어와서다(두 세션의 손이 같은 방향). expel-window-from-column 은 포커스와 무관하게 맨 아래 창을 뱉는다("Expel the
  bottom window from the focused column").
- **라이싱 스크립트**: spawn 은 $HOME 을 확장하지 않아 sh -c 를 거친다. PATH 에 안 올리는 건 라이싱 중 스크립트를 고칠
  때마다 rebuild 하지 않으려는 것이다. RICE_REPO 를 먼저 보고, 빗나가면 키가 조용히 아무 일도 안 한다(apps/doctor 가
  짚는다). yazi 는 터미널이 필요해 ghostty 를 띄운다(kitty 그래픽 미리보기). Mod+Shift+R 은 RiceSwitcher 트리거를 친 채
  런처를 연다(화면 셰이더 축은 하이프랜드에서만 뜬다).
- **밝기** `increment(step, device)` — 하나만 넘기면 DMS 가 "Too few arguments provided" 로 조용히 거절한다. 빈 문자열은
  기본 장치.
- **버린 바인드**: Mod+L 잠금(IJKL 이 L 을 가져감, 잠금은 Mod+Escape 파워메뉴), Mod+Comma DMS 설정 GUI(런처에서 이름으로),
  Mod+Shift+E quit(Mod+E 와 Mod+Shift+F 사이라 오타 한 번에 세션이 날아감, 로그아웃은 파워메뉴), Mod+Home/End
  focus-column-first/last(하이프랜드에 동작이 없어 세 곳을 맞추려면 여기만 남길 수 없음, [hyprland-binds.md](hyprland-binds.md)).
- **클릭 포커스**: 세 WM 공통(하이프랜드 follow_mouse = 0, rift-grid focus_follows_mouse = false). 이유는
  [hyprland.md 의 입력 절](hyprland.md#입력)과 같다.
- **휠 클릭 스크롤**: 미들 드래그는 사라지고 휠 클릭은 뗀 순간에 나간다. scroll-button-lock 은 휠 클릭을 죽여 안 켠다.
  니리는 mouse/touchpad 설정이 갈라져 하이프랜드처럼 장치를 짚을 필요가 없는 대신, `modules/nixos/pointer` 의 가상
  포인터에도 걸린다 — Caps+9 를 누른 채 wasd 로 젓는 것도 스크롤이다(그 손은 q/e 로 휠이 있어 잃는 건 키보드 마우스의
  미들 드래그뿐).

## animations.kdl — 창 열림/닫힘 셰이더

니리는 애니메이션 안에서만 셰이더를 받는다. 화면 전체 훅은 26.04 설정 표면에 없다(`screen-shader` 같은 노드 없음).
그래서 정상 상태 비용이 0 이다. 니리가 감싸는 본문:

```glsl
varying vec2 niri_v_coords;
uniform vec2 niri_geo_size;
uniform sampler2D niri_tex;
void main() {
    vec3 coords_geo = niri_input_to_geo * vec3(niri_v_coords, 1.0);
    vec3 size_geo = vec3(niri_geo_size, 1.0);
    vec4 color = open_color(coords_geo, size_geo);
    gl_FragColor = color;
}
```

정의할 건 open_color / close_color 다. 내용은 niri_geo_to_tex 로 텍스처 좌표를 만들어 niri_tex 에서 뽑고, 진행도는
niri_clamped_progress.

- **coords_geo 는 0..1 정규화다(픽셀 아님).** 짝인 size_geo 가 논리 픽셀이라 착각하기 쉽다 — step(1.5, coords_geo.x) 를
  칠해 보면 창 전체가 한 색이다(실측). 픽셀로 가정하면 중심을 size_geo/2(≈1000)로 잡아 마스크가 늘 0 이 되어 애니메이션
  내내 창이 안 그려진다(증상이 "셰이더 무시"가 아니라 "창이 사라짐"). 픽셀 단위 값(선 두께)은 size_geo 로 나눠 쓴다.
- GLSL ES 1.00(#version 100), texture2D. KDL 원시 문자열 안이라 #define 대신 const.
- 색은 프리멀티플라이드 알파(vec4(f) = 불투명 흰색 × f).
- 곡선은 linear 로 두고 완급은 셰이더 안에서 구간별로 준다.
- 저장 즉시 반영된다(니리는 include 한 파일도 감시). 파일을 통째로 지우면 니리 기본 애니메이션.

## 프로필

`apps/rice/switch` 가 profiles/<이름>/niri.kdl 을 `~/.config/niri/profile.kdl` 로 복사하고 config.kdl 의
`include "profile.kdl"` 이 읽는다(니리는 include 된 파일도 감지). 색은 dms/colors.kdl 이 DMS 테마에서 넣으므로 프로필은
형태뿐이다. 프로필 규칙의 정본은 `modules/nixos/niri/rice/profiles/README.md` 이고, 여기는 프로필마다 고른 이유만 적는다.

- **matugen**: 색 경로는 월페이퍼 → matugen → dms/colors.kdl(니리) + dank-theme.toml(터미널) + DMS 팔레트. 보더 2px 는
  active-color 가 눈에 들어오게(1px 면 안 보인다).
- **frosted**: 블러는 DMS 쪽(dms.json 의 blurEnabled)이다 — 니리 자체엔 블러가 없고 셸이 자기 레이어를 블러하며, 프로필은
  블러가 보일 여백(넓은 갭)을 만든다. 곡률 큰 창에서 얇은 보더는 계단처럼 보여서, 활성 창에만 그려지는 포커스 링만 남긴다.
- **amoled**: 링과 보더를 겹치면 검정 배경에서 테두리가 두 겹으로 보이고, OLED 에서 그림자는 검정 위 검정이라 안 보이면서
  합성 비용만 든다.
