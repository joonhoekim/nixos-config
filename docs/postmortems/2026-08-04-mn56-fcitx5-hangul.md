# 2026-08-04 — mn56: 한/영이 안 먹는데, 키는 멀쩡히 도착하고 있었다

환경: NixOS 26.11, Hyprland 0.56 (uwsm), fcitx5 5.1.21 + fcitx5-hangul 5.1.10,
keyd 2.6.0, mn56. 세션은 wayland, fcitx5 는 `waylandFrontend = true`
(input-method-v2, `GTK_IM_MODULE`/`QT_IM_MODULE` 없음).

"Right Alt 로 한/영이 안 바뀐다. keyd 때문인 것 같다"로 시작했다. **keyd 는
무죄였고, 조사가 끝날 때까지 진짜 원인은 잡지 못했다.** 이 문서가 남아 있는 이유가
그거다 — 다음에 같은 걸 만나면 여기부터 시작하면 된다.

---

## 증상

Right Alt 를 눌러도 IME 가 안 바뀐다. VS Code, Chrome, Ghostty 전부 동일. 에러는
어디에도 없다. fcitx5 는 살아 있고 영문 입력은 정상이다.

---

## 아니었던 것 — 네 홉을 전부 증거로 지웠다

의심 순서가 곧 키가 지나가는 경로다. 각 홉마다 **추측이 아니라 관측**을 하나씩 붙였다.

| 홉 | 확인 방법 | 결과 |
|---|---|---|
| keyd 리맵 | `sudo evtest /dev/input/event*`(keyd virtual keyboard) | `code 122 (KEY_HANGUEL)` press/release 쌍 정상 |
| xkb 매핑 | `keycodes/evdev`, `symbols/pc` 직접 grep | `<HNGL> = 130`, `pc105` 에서 `Hangul` keysym |
| 컴포지터 전달 | fcitx5 keytrace 로그 | `Key(Hangul states=0) … keycode: 130` |
| fcitx5 설정 | dbus `FullInputMethodGroupInfo` | `('Default', 'hangul', 'us', …)` — hangul 존재, 기본 IM 맞음 |

`symbols/pc` 는 섹션이 `pc105` 하나뿐이라 `us` 레이아웃만 써도 Hangul keysym 이
딸려 온다. 이건 한 번 확인해 두면 다시 의심할 필요가 없다.

그리고 fcitx5 의 컴파일 내장 기본 `TriggerKeys` 에 `Hangul` 이 들어 있다 —
설정 파일 없이도 원래 먹어야 한다.

```sh
strings "$(readlink -f …/lib/libFcitx5Core.so)" | grep -xE 'Control\+space|Hangul'
```

---

## 관측된 진짜 증상

fcitx5 는 키를 **받았고, 소비까지 했는데, 전환을 안 했다.**

```
waylandimserverv2.cpp:526] Hangul IsRelease=0
instance.cpp:961] KeyEvent: Key(Hangul states=0) … Release:0 keycode: 130 program: code
inputcontext.cpp:342] KeyEvent handling time: 0ms result:1     ← 소비됨
```

`result:1` 은 `filterAndAccept()` 가 걸렸다는 뜻이다. fcitx5 의 트리거 키 처리는
**누를 때** `trigger()` 를 부르고 `filterAndAccept()` 하므로, 여기까지 온 이상
`toggle()` 또는 `enumerate()` 가 실행됐어야 한다.

그런데 **330 번쯤 누르는 동안 `activateInputMethod` 로그가 한 줄도 없었다.** 로그에
찍힌 activate/deactivate 는 전부 포커스 이동에 따른 `keyboard-us` 뿐이었다.

```
instance.cpp:2452] Activate: [Last]: [Activating]:keyboard-us
instance.cpp:2507] Deactivate: [Last]:keyboard-us [Deactivating]:keyboard-us
```

---

## 원인 — 못 잡았다

`fcitx5-remote -o` (activate) 한 번으로 풀렸다. **프로세스 재시작도, 설정 파일 변경도
없었다** — PID 가 처음부터 끝까지 그대로였다. 그 뒤로 같은 키가 정상 동작했고,
로그에도 키 이벤트 안에서 전환이 찍혔다.

```
KeyEvent: Key(Hangul …) Release:0 keycode: 130 program: code
  Deactivate: [Last]:hangul [Deactivating]:hangul
  Activate:   [Last]: [Activating]:keyboard-us
KeyEvent handling time: 13ms result:1
```

즉 **fcitx5 의 input-context 런타임 상태가 끼어 있었다.** 설정 문제가 아니었고,
한 번 풀린 뒤로는 재현되지 않아 그 이상은 추적하지 못했다. 여기서 멈춘 것을 그대로
적어 둔다 — 추측으로 메우면 다음 사람이 그 추측을 사실로 읽는다.

---

## 조사 중에 나온 별개의 함정 — 세 번째 IM

이건 위 증상의 원인은 **아니다**(그랬다면 전환 로그가 찍혔어야 한다). 다만 실재하고,
겪으면 똑같이 "한/영이 반쯤 고장난" 것처럼 보인다.

프로필에 IM 이 셋 있었다: `keyboard-us`, `hangul`, `keyboard-kr`.

`Instance::trigger()` (`src/lib/fcitx/instance.cpp`) 는 이렇게 갈린다.

```cpp
if (totallyReleased) {
    toggle(ic);
    inputState->firstTrigger_ = true;
} else {
    if (!d->globalConfig_.enumerateWithTriggerKeys() ||
        (inputState->firstTrigger_ && inputState->isActive()) ||
        (d->globalConfig_.enumerateSkipFirst() &&
         d->imManager_.currentGroup().inputMethodList().size() <= 2)) {
        toggle(ic);
    } else {
        enumerate(ic, true);
    }
    inputState->firstTrigger_ = false;
}
```

`EnumerateWithTriggerKeys` 기본값이 `true` 고 목록이 셋이면 `size() <= 2` 가지가
**절대 안 걸린다.** 트리거가 `enumerate()` 로 새서 순환이 된다:

`keyboard-us → hangul → keyboard-kr → keyboard-us …`

`keyboard-kr` 은 **엔진이 아니라 xkb 레이아웃**이다. `kr` 은 US QWERTY 에 키 두어 개
붙은 것이라 고르면 알파벳이 나온다. 한글은 언제나 hangul *엔진*에서 나오지 레이아웃에서
나오지 않는다. 결국 세 상태 중 둘이 영문이라, 한/영을 눌러도 안 바뀌는 것처럼 느껴진다.

---

## 고침

`modules/nixos/korean.nix` (커밋 `a29d6d6`).

1. `Groups/0/Items/2` (`keyboard-kr`) 제거 → 목록 둘.
2. `settings.globalOptions` 신설 → `/etc/xdg/fcitx5/config`. **이 파일은 그전까지
   아예 없었다** — 모든 핫키가 컴파일 내장 기본값이었다.

```ini
[Hotkey]
EnumerateWithTriggerKeys=False

[Hotkey/TriggerKeys]
0=Hangul
1=Control+space
```

`Control+space` 는 일부러 남겼다. Hangul 경로 자체를 의심할 때 탈출구가 필요하다 —
이번 조사에서 그게 없어서 초반에 층을 못 갈랐다.

### 함정 1 — `"False"` 지 `false` 가 아니다

처음엔 Nix 불리언으로 썼다. 생성된 ini 가 소문자였다.

```ini
EnumerateWithTriggerKeys=false      # ← 아무 효과 없음
```

nixpkgs 26.11 의 fcitx5 모듈은 이 파일을 **정규화 없이** 쓴다.

```nix
(optionalFile "config" (lib.generators.toINI { }) cfg.settings.globalOptions)
```

그리고 fcitx5 쪽은 `"True"`/`"False"` 만, **대소문자 구분해서** 받는다
(`src/lib/fcitx-config/marshallfunction.cpp`).

```cpp
bool unmarshallOption(bool &value, const RawConfig &config, bool) {
    if (config.value() == "True" || config.value() == "False") {
        value = config.value() == "True";
        return true;
    }
    return false;          // ← 나머지는 조용히 기본값 유지
}
```

`return false` 라 **에러도 경고도 없이 기본값으로 되돌아간다.** 맞아 보이는데 아무것도
안 하는 설정이 된다. 같은 파일의 `AutoReorder = "True"` 가 원래 따옴표였던 게 이 이유다.
빌드 산출물을 눈으로 확인하는 것 말고 잡을 방법이 없다.

```sh
nixos-rebuild build --flake .#mn56 && cat ./result/etc/xdg/fcitx5/config
```

### 함정 2 — 사용자 프로필이 선언적 설정을 가린다

fcitx5 는 `~/.config/fcitx5/*` 를 `/etc/xdg/fcitx5/*` 보다 **먼저** 읽는다. 그리고
`~/.config/fcitx5/profile` 은 fcitx5 **자신이 쓰는 파일**이다 — 저장 시점
(`AutoSavePeriod`, 기본 30 분)과 종료 때. 그래서 한 번이라도 돌아간 기기에는 반드시
있고, `switch` 만으로는 아무 변화가 없다. 지워야 한다.

순서가 중요하다. 켜 둔 채로 지우면 다음 저장 때 그대로 돌아온다.

```sh
systemctl --user stop app-org.fcitx.Fcitx5@autostart.service
rm ~/.config/fcitx5/profile
systemctl --user start app-org.fcitx.Fcitx5@autostart.service
```

`i18n.inputMethod.fcitx5.ignoreUserConfig = true` 로 이걸 아예 막을 수는 있는데,
그러면 fcitx5 가 무엇도 영구화하지 못한다(설정 GUI 가 쓰는 것 포함). 여기서는 안 켰다.

---

## 다음에 빨리 잡는 법

```sh
# 0. 제일 먼저. 이걸로 풀리면 이번과 같은 런타임 상태 문제다 — 설정을 뒤지지 말 것
fcitx5-remote -o

# 1. fcitx5 가 키를 받고 있나. 이 한 줄이 조사의 절반이다
gdbus call --session --dest org.fcitx.Fcitx5 --object-path /controller \
  --method org.fcitx.Fcitx.Controller1.SetLogRule "keytrace=5"
journalctl --user -fu 'app-org.fcitx.Fcitx5@autostart.service'
#   Key(Hangul …) keycode: 130  이 뜨면 keyd·xkb·컴포지터는 전부 무죄다
#   result:1 인데 Activate 가 안 따라오면 → 이번 건과 같은 증상
gdbus … --method org.fcitx.Fcitx.Controller1.SetLogRule ""      # 끄기. 매우 시끄럽다

# 2. 그룹에 뭐가 들어 있나 (셋이면 enumerate 로 샌다)
gdbus call --session --dest org.fcitx.Fcitx5 --object-path /controller \
  --method org.fcitx.Fcitx.Controller1.FullInputMethodGroupInfo "Default"

# 3. keyd 가 진짜로 뭘 내보내나. 키는 keyd 가상 키보드에서 봐야 한다
grep -l 'keyd virtual keyboard' /sys/class/input/event*/device/name
sudo evtest /dev/input/eventN        # code 122 (KEY_HANGUEL) 이 나와야 정상

# 4. 지금 먹고 있는 설정이 어느 파일인지
ls ~/.config/fcitx5/{config,profile} /etc/xdg/fcitx5/{config,profile}
```

**`pgrep -x fcitx5` 는 아무것도 안 뱉는다.** 프로세스 이름이 `.fcitx5-wrapped` 라서
그렇다. 살아 있는데 죽은 줄 알고 엉뚱한 데를 판다. `systemctl --user status` 를 쓴다.

**`fcitx5-remote -n` 도 곧이곧대로 믿지 않는다.** 마지막으로 포커스를 가졌던 input
context 를 대상으로 답하기 때문에, 터미널에서 물으면 지금 보고 있는 창의 상태가 아닐
수 있다. 이번에도 초반에 `-s hangul` 이 안 먹는 것처럼 보여서 한참 헤맸다.

---

## 배울 것

**"X 때문인 것 같다"에서 시작하되, X 부터 지운다.** 이번 신고는 "Right-Alt keyd 때문"
이었고 keyd 는 무죄였다. 경로가 네 홉이면 홉마다 관측을 하나씩 붙여 지워 나가는 게
결국 제일 빠르다 — 각 홉이 키를 다른 이름으로 부르기 때문에(`hangeul` / 122 / `<HNGL>`
/ 130 / `Hangul`) 머릿속으로는 검산이 안 된다. 그 체인은 이제
`modules/nixos/korean.nix` 헤더에 적혀 있다.

**소비됐다(`result:1`)와 처리됐다는 다르다.** 키가 도착했고 누군가 먹었다는 사실이
"동작했다"를 뜻하지 않는다. 이번 건은 정확히 그 틈에 있었고, 그래서 앱 쪽에서는
"키가 씹힌다"로만 보였다.

**원인을 못 찾았으면 못 찾았다고 적는다.** 조사 중에 실재하는 함정(`keyboard-kr`)을
하나 찾았고 그건 고쳤지만, 그게 신고된 증상의 원인이라는 증거는 없다. 둘을 붙여서
"고쳤다"로 적고 싶은 유혹이 있는데, 그러면 재발했을 때 다음 사람이 이미 지워진
가능성을 다시 뒤진다.

**설정이 조용히 무시되는 조합을 경계한다.** `false` vs `"False"` 는 생성기(정규화 없는
`toINI`)와 소비자(대소문자 구분 + 실패 시 기본값 유지)가 각각은 합리적인데 맞물리면
침묵하는 경우다. **에러를 안 내는 설정은 산출물을 눈으로 봐야 한다.**
