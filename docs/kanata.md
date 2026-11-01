# kanata.kbd — 수치와 OS 차이

kanata 는 키 입력을 가로채 레이어·탭홀드·포인터 이동을 거는 크로스플랫폼 키 리맵 프로그램이다.
`modules/shared/kanata/kanata.kbd` 는 macOS 와 Windows 가 같이 쓰는 Caps Lock 레이어다. 이 문서는 그 파일의 수치와 OS
차이의 근거를 적는다.

- 배치·검증·설치: `modules/shared/kanata/README.md`
- 정본: `modules/nixos/keyboard.nix`(keyd)와 `modules/nixos/pointer/pointerd.py`. 키 배치와 수치는 거기서 옮긴다 —
  [keymap.md](keymap.md).
- macOS 배선(드라이버, 서명, launchd): [macos-internals.md](macos-internals.md#kanata-배선-modulesdarwinkanatanix)

OS 마다 다른 것은 `(platform ...)` 블록의 별칭 몇 개뿐이다. `kanata --check` 는 지금 OS 의 platform 블록만 읽는다.

시험 실행(Windows, 콘솔 로그가 보이는 tty 빌드, Ctrl+C 로 끝):

```powershell
& "$env:LOCALAPPDATA\Programs\kanata\kanata_windows_tty_winIOv2_x64.exe" `
    --cfg modules\shared\kanata\kanata.kbd
```

macOS 에서는 launchd 데몬이 띄운다(`modules/darwin/kanata.nix`). 한/영은 macOS 에서 오른쪽 ⌘ → F18 이고, F18 은 "입력 소스
다음으로" 단축키다(`hosts/darwin/common.nix` 의 AppleSymbolicHotKeys 61).

## 오른쪽 Alt (Windows 한/영)

kanata 는 오른쪽 Alt 를 아예 잡지 않는다(`process-unmapped-keys (all-except ralt)`). 한/영은 Windows 한국어 자판 배열이
스캔코드 E038 을 VK_HANGUL 로 번역해서 한다(`MapVirtualKeyA(0xE038, 3) = 0x15`). 잡아서 다시 내보내면 두 가지가 깨진다:

- `ralt kana` 로 매핑하면 왼쪽 Alt 가 나간다. kanata 의 스캔코드 표(`src/oskbd/windows/scancode_to_usvk.rs` `osc_to_u16`)에
  KEY_HANGEUL 이 없어서 `MapVirtualKeyA(VK_HANGUL)` 로 떨어지고, 그 값이 0x38(왼쪽 Alt)이다.
- 그대로 통과시키면 전환은 되지만 kanata 는 RAlt 를, Windows 는 VK_HANGUL 을 누른 것으로 안다. 상태 동기화
  (`src/kanata/windows/llhook.rs`, GetAsyncKeyState)가 이 차이를 매번 "Unexpected keycode ... Clearing kanata states: RAlt"
  에러로 찍는다.

macOS 에서는 처리하지 않은 키도 kanata 가 그대로 내보내므로 오른쪽 ⌥ 는 평범한 ⌥ 다.

## 포인터

kanata 의 틱은 1ms. `(movemouse-* 간격 거리)` 는 "간격 ms 마다 거리만큼".

- **Windows**: 10ms 마다 7px = 700 px/s. 상대 이동(MOUSEEVENTF_MOVE)이라 Windows 의 포인터 속도와 "포인터 정확도 향상"(가속)을
  그대로 탄다. 가속이 켜져 있으면 1px 짜리 저속 이동이 더 작게 깎여 체감 속도가 수치와 어긋난다.
- **macOS**: 커서 위치를 포인트 단위로 직접 옮긴다(`src/oskbd/macos.rs` `move_mouse`, CGEvent 를 HID 탭에 게시). 가속을 타지
  않는다. 10ms 마다 15pt = 1500 pt/s 는 실사용에서 고른 값이다(Karabiner 의 3000 보다 조금 빠르게 느껴지고, 그쪽이 더 쓰기
  좋다).
- **Shift 저속**: `movemouse-speed 14` 로 거리에 14% 를 곱한다(Windows 1px/10ms = 100 px/s). 배율은 이동을 한 번 보낼 때마다
  다시 계산되므로(`src/kanata/mod.rs` `handle_move_mouse`) 움직이는 도중에 Shift 를 눌러도 그 자리에서 느려진다 — pointerd
  가 Shift 를 직접 읽는 것과 같은 동작. Shift 는 [nav] 가 아니라 기본 레이어에 건다: Caps 보다 먼저 눌렀을 때도 저속이 걸려야
  하고, [nav] 밖에서는 움직이는 포인터가 없으니 배율은 아무 일도 안 한다.

## 휠

67ms 마다 한 번 ≈ 15번/s.

- **Windows**: 거리 120 = 휠 한 칸(WHEEL_DELTA).
- **macOS**: 거리를 줄 수로 그대로 쓴다(`macos.rs` `scroll`, SCROLL_WHEEL_EVENT_DELTA_AXIS_1). 120 을 주면 한 번에 120줄이
  넘어간다. Windows 한 칸이 보통 3줄이라 3. 방향 부호는 실측 전이다 — q 가 아래로 가면 q/e 를 맞바꾼다.

## 줄 처음/끝과 찾기 (macOS)

macOS 의 Home/End 는 커서가 아니라 문서 처음·끝으로 화면만 옮기고, 텍스트 뷰의 줄 처음·끝은 ⌘←/⌘→ 다. 찾기도 Ctrl 이 아니라 ⌘.

## F열 (macOS)

Apple 키보드는 F1–F12 를 그대로 보내고, 이를 Media Keys 로 바꾸는 것은 macOS 의 Apple 키보드 드라이버다. kanata 를 거친
키는 Karabiner 가상 키보드에서 나오는데 이건 Apple 키보드가 아니라서 그 변환을 받지 못한다 — 매핑이 없으면 fn 을 누르든
말든 F열이 F1–F12 가 된다. 그래서:

- 기본값을 Media Keys 로 매핑하고, fn 을 누르는 동안(fkeys 레이어) Standard Function Keys 로 쓴다.
- fn 입력도 그대로 전달하므로 fn+←(Home) 같은 macOS fn 조합과 🌐 단축키는 유지된다.
- 배치는 M4 MacBook Pro(Mac16,8)의 키캡. F6(방해 금지 모드)은 대응하는 HID usage 가 없어서 F6 그대로 둔다.
- 시스템 설정의 "F1, F2 등의 키를 표준 기능 키로 사용" 은 더 이상 반영되지 않는다.

Windows 에서는 키보드 펌웨어가 Fn 을 처리하고 fn 이 kanata 까지 오지 않는다.

## Caps 의 tap-hold-press

다른 키가 눌리는 순간 홀드로 확정된다. Caps+i 를 빠르게 굴려도 i 가 글자로 새지 않는다. 다른 키 없이 200ms 를 넘겨 떼면
아무 일도 하지 않는다(keyd 의 overload 는 이때도 Caps Lock 을 토글한다).
