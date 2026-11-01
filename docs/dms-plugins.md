# DMS 플러그인 — RiceSwitcher 와 TouchControls

DankMaterialShell(DMS)은 Quickshell 기반 데스크톱 셸(바, 런처, 컨트롤 센터, 알림, 잠금 화면)이고, QML 플러그인으로
런처 항목이나 바(DankBar) 조각을 더할 수 있다. `modules/nixos/dms` 는 이 저장소의 플러그인 둘을 심는다.

## 이 모듈의 자리

DMS 플러그인만 맡는다. 셸 자체(programs.dms-shell)는 `modules/nixos/niri` 에서 켠다 — DMS 를 처음 들여온 자리이고
세션·systemd 배선이 같이 있어야 읽힌다([niri](niri.md)). 두 세션이 같이 쓰는 조각을 niri 쪽에 두면 하이프랜드 전용
축(화면 셰이더)이 니리 모듈 안에 숨기 때문에 갈랐다.

## RiceSwitcher

면이 둘인 composite 플러그인이다(PLUGINS/plugin-schema.json 의 components).

**launcher**: 라이싱 축을 런처(Mod+space, `:` 트리거; Mod+Shift+R 은 `dms ipc call spotlight toggleQuery ":"`)에서
고른다. 값도 목록도 QML 에 없다 — `apps/rice/menu` 가 JSON 으로 주고, 그건 축별 스위처에게 묻는다
([rice-tools.md](rice-tools.md#런처-메뉴-뒤판--appsricemenu)). 축을 추가해도 QML 은 그대로다.

**widget**: DankBar 조각 하나, 누르면 스튜디오([rice-studio.md](rice-studio.md))를 띄울 뿐이다.
- 셰이더 상태를 모르고 폴링도 안 한다(상시로 뜬 자리의 주기 호출은 비싸고, 상태를 들면 DMS 안에 셰이더 지식이 다시 고인다).
- popoutContent 를 안 쓴다(쓰면 스튜디오가 DMS 안으로 들어온다). pillClickAction 을 인자 없는 함수로 두면 팝아웃 대신
  불린다(Modules/Plugins/PluginComponent.qml 의 onClicked — `pillClickAction.length === 0` 일 때 좌표 없이).
- 이미 떠 있으면 rice-studio 가 -n 으로 나간다(여기서 세면 손으로 닫았을 때 낡는다).
- 체크아웃 위치는 RICE_APPS · RICE_REPO · ~/nixos-config 순(hyprland/rice/studio/Rice/*.qml 과 같은 규칙).

**화면 셰이더는 여기 없다.** 셰이더 축만 성질이 달라(여러 장을 순서대로, 조합마다 비용 곱, 칸마다 손잡이) 런처 항목
계약에 넣으면 QML 이 갈래 이름을 자르고 탭 수를 곱하고 한도(64)를 적고 `add`/`save` 동사를 알게 된다. 그래서 별도
창(apps/rice/studio)으로 나갔고, 여기는 여는 단추와 탈출구(off · 다음 것)만 남았다.

**런처 플러그인 계약**(PLUGINS/LauncherExample/README.md): `property var pluginService`, `property string trigger`,
`signal itemsChanged()`, `function getItems(query)`, `function executeItem(item)`. getItems 는 동기여야 해서 미리 받은
캐시를 돌려주고 새 값이 오면 itemsChanged() 를 낸다. lastRefresh 창으로 열 때마다 셸을 부르지 않고, 값을 걸면 0 으로
무효화한다.

**항목 구성:**
- 값 목록은 축마다 "고르기" 한 줄로 접는다(한 줄씩이면 대부분이 "지금 안 고를 것"). 동작(스튜디오 열기, 월페이퍼
  무작위)은 안 접는다 — 기준은 개수가 아니라 성격이다.
- 이름·부제가 한글이라 `studio`·`wallpaper` 같은 영어 질의가 안 겹친다. 그래서 축 id 와 rice-menu 의 영어 별칭
  (axis.keywords · actions[].keywords)을 keywords 에 싣는다(Scorer.js 는 이름·부제가 0점일 때 keywords 를 본다,
  Scorer.js:133).
- 드릴다운: 런처가 같은 질의로 한 번 더 점수 필터를 걸어(`if (itemScore > 0 || !query)`), 질의 `term` 과 이름 "터미널 ·
  crt" 가 안 겹치면 전부 0점 탈락으로 목록이 빈다. 런처에 질의를 바꿀 훅이 없어 drill: 은 밖에서 다시 연다(항목 실행 시
  런처가 닫혀 순서가 맞다). 질의는 한글 라벨이 아니라 축 id(검색창에 남는 글자)다.
- 검색은 접힌 것을 뚫는다(`:amoled`). 체크 표시는 이름에 붙인다(런처가 배지를 안 그린다).
- 창을 띄우는 동작은 rice-menu 의 actions[].detach 로 판단한다(붙잡으면 창이 닫힐 때까지 Process 가 살고 토스트도 그때 뜬다).
- 명령은 sh -c 없이 argv 로 부른다. 스위처는 거절 이유를 stdout(rice_reject)에 쓰고 목록을 뒤에 붙이므로 전체를 모은다.

## TouchControls

터치 기계에서 화면 키보드·자동 회전·태블릿 모드를 손가락으로 켜고 끄는 바 조각이다. 화면 키보드를 여는 길이 Mod+B
하나뿐이면 화면을 접은 자세에서 열 수 없다.

- 상태는 `touch-state` JSON 이 준다(sysfs 위치, 자판 보임 판정은 하이프랜드 레이어, 회전 데몬 상태 파일 — 전부 셸 쪽,
  [galaxy-chromebook-1](galaxy-chromebook-1.md#터치-자세-화면-키보드-자동-회전-태블릿-모드)). 여기는 키 세 개만 안다.
- 폴링하지 않는다. 팝아웃이 열릴 때(자판은 Mod+B·hide 키·태블릿 훅으로도 움직여 지난 값을 못 믿는다)와 누른 직후 한 번
  읽는다. execDetached 라 끝을 몰라 조금 기다린다 — osk 는 신호를 받고 다음 프레임에야 레이어가 생긴다. 낙관적으로
  뒤집으면 실패 때 UI 만 거짓말한다.
- `touch-state` 가 없는 머신에서는 셋 다 off(조용히 깨지는 것보다 낫다).
- `local.dms.touchControls.enable` 은 기본 꺼짐이다. `touch-state` 와 세 CLI 는 터치 하드웨어 호스트
  (hosts/nixos/galaxy-chromebook-1/touch.nix)만 깐다.

## 바에 올리는 것은 손으로

조각 배치는 settings.json 의 `barConfigs[].{left,center,right}Widgets` 이고, 플러그인 조각 id 는 플러그인 id 다
(Modules/DankBar/WidgetHost.qml 의 getWidgetComponent — componentMap 에 없으면 `:` 앞을 플러그인 id 로 본다). jq 로 끼울
수 있지만 안 한다 — 배치는 취향이라 뺀 것을 리빌드가 도로 넣으면 매번 되풀이된다. 한 번만: DMS 설정 → DankBar → 조각
목록에서 Rice(또는 settings.json 의 rightWidgets 에 "riceSwitcher").

settings.json 을 손으로 고쳤으면 `dms restart`. 돌고 있는 DMS 는 남이 고친 settings.json 을 다시 안 읽는다(시작 때 한
번, 그 뒤엔 자기가 쓸 때만). 증상: "플러그인은 loaded 인데 바에 아무것도 없다" — `dms ipc call plugins list` 도 [loaded].

## 왜 /etc/xdg 가 아니라 $HOME 에 심는가

DMS 는 `~/.config/DankMaterialShell/plugins/`(사용자)와 `/etc/xdg/quickshell/dms-plugins/`(시스템) 두 곳에서 찾는다
(Services/PluginService.qml). environment.etc 는 선언적이지만 스토어 심링크라 고쳐 볼 수 없다. 사용자 쪽이면 QML 을
고칠 때 DMS 가 폴더를 감시하다 바로 다시 읽는다. 되받기는 apps/rice/save.

## plugin_settings.json

파일만 놓아서는 안 뜬다 — DMS 는 `enabled: true` 를 봐야 로드한다(PluginService.qml 의
`SettingsData.getPluginSetting(id, "enabled", false)`). 그 값은 plugin_settings.json 에 산다. DMS 가 켜고 끌 때마다 다시
써서 라이브가 기준선에서 벗어나 있는 게 정상이고, rice_sync 는 손을 뗀다([rice-seeding](rice-seeding.md)의 판정표 3·4행).
그대로 두면 새 키가 안 들어가 "파일은 깔렸는데 런처에 안 뜬다"가 되므로, rice_ensure 취지로 그 키만 없을 때 끼운다. 끈
것은 도로 켜지 않는다(키가 있으면 false 여도 그대로). 폴더 이름과 매니페스트 id 가 달라 둘 다 적는다(폴더는 rice_sync,
id 는 enabled).

## plugin.json 을 고쳤으면 셸 재시작

QML 은 저장 즉시 반영되지만 매니페스트는 아니다. `dms ipc call plugins reload <id>` 는 컴포넌트만 다시 읽고, plugin-scan
도 아는 매니페스트는 건너뛴다. manifest 에 키를 새로 넣으면(예: settings) 증상은 "설정 패널이 있는데 플러그인 목록만
보인다". `dms restart` 한다. 값 조절이나 QML 손볼 때는 필요 없다.
