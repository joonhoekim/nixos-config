# Karabiner — Caps Lock 레이어 (네비게이션 + 마우스)

`karabiner.json`의 설정 설명. **Caps Lock을 홀드**하는 동안 손이 홈로우를 떠나지 않는
레이어가 열린다. 오른손은 커서 이동([TouchCursor](https://github.com/martin-stone/touchcursor)
배치 그대로), 왼손은 마우스다. 트리거만 TouchCursor 기본값(스페이스) 대신 Caps Lock이라
윈도우 머신과 같은 손가락 기억을 공유한다.

NixOS 쪽은 같은 배치를 keyd + 전용 데몬으로 구현한다:
[`modules/nixos/keyboard.nix`](../../../nixos/keyboard.nix),
[`modules/nixos/pointer/`](../../../nixos/pointer/).

> 두 개의 보관 파일이 함께 있고, 둘 다 어디에서도 로드되지 않는다.
> - `karabiner.json.vim` — 이 자리에 있던 vim/neovim 배치 버전. 왜 접었는지는
>   [`modules/nixos/keyboard.nix.vim`](../../../nixos/keyboard.nix.vim) 헤더에 길게 적혀 있다.
> - `karabiner.json.touchcursor` — 스페이스 트리거를 쓰던 원본 TouchCursor 설정.

## 트리거 동작 (Caps Lock)

| 입력 | 결과 |
|------|------|
| Caps Lock **탭** (혼자 눌렀다 뗌) | 일반 Caps Lock 토글 |
| Caps Lock **홀드** | 홀드하는 동안 레이어 활성화 (`touchcursor_mode = 1`) |

내부적으로 홀드 시 `touchcursor_mode` 변수를 1로 세팅하고, 뗄 때 0으로 되돌린다. 레이어의
모든 매핑은 이 변수가 1일 때만 발동한다. 매핑되지 않은 키는 홀드 중에도 **그냥 그 글자
그대로** 입력된다.

## 오른손 — 커서 (Caps Lock 홀드 중)

| 키 | 동작 (macOS) | | 키 | 동작 (macOS) |
|----|------|-|----|------|
| `i` `j` `k` `l` | ↑ ← ↓ → (역T) | | `p` / `m` | 뒤로 / 앞으로 삭제 |
| `u` / `o` | 줄 처음 / 끝 (⌘← / ⌘→) | | `y` | Insert |
| `h` / `n` | PageUp / PageDown | | `/` | 찾기 (⌘F) |

## 왼손 — 마우스 (Caps Lock 홀드 중)

| 키 | 동작 | | 키 | 동작 |
|----|------|-|----|------|
| `w` `a` `s` `d` | 포인터 ↑ ← ↓ → | | `q` / `e` | 휠 위 / 아래 |
| `⇧`+`wasd` | 같은 방향, 저속 | | `⇧q` / `⇧e` | 좌 / 우 스크롤 |
| `f` / `r` | 왼쪽 / 오른쪽 클릭 | | `8` `9` `0` | 왼쪽 / 가운데 / 오른쪽 버튼 |

클릭이 두 벌이다. `f`/`r`은 조향하는 손 안에 있어서 마우스가 한 손으로 끝나고, `8`/`9`/`0`은
반대 손이 놀 때 쓴다(가운데 버튼은 이쪽에만 있다).

버튼은 **누르는 동안만** 눌린다. 그래서 `Caps+f`를 잡은 채 `wasd`로 드래그하고, `Caps+⇧f`는
그냥 ⇧클릭이다 (`optional: ["any"]`라 Shift가 그대로 통과한다).

이 자리에는 원래 vim에서 빌려온 `w`/`e`/`b`(단어 이동)와 `g`/`⇧g`(문서 처음·끝)가 있었고,
마우스에 자리를 내주면서 전부 없앴다. 에디터가 이미 더 잘 하는 일을 중복한 키들이었고,
물리 마우스를 대신할 후보는 이쪽뿐이었다.

## Shift 조합

**오른손 바인딩은 전부 unshifted**라서 Shift는 커맨드의 일부가 되는 일이 없고, 통째로
**선택 확장**에 쓸 수 있다. `Caps+⇧j` = 왼쪽으로 선택, `Caps+⇧o` = 줄 끝까지 선택.

Shift가 의미를 갖는 건 왼손뿐이다 — 저속 이동과 가로 스크롤. 구현은 `mandatory: ["shift"]`
규칙을 기본 규칙 **위에** 얹는 방식이고, 그래서 이동을 시작한 **뒤에** Shift를 눌러도
느려지지는 않는다 (Karabiner는 키를 누르는 순간 규칙을 확정한다). NixOS 쪽은 데몬이 Shift
키를 직접 보기 때문에 이동 중 전환이 된다. 지금 두 OS가 갈리는 유일한 지점이다.

## 설계 노트

- **역T 화살표**: `ijkl`은 물리 화살표 클러스터와 모양이 같아서 방향을 외울 게 없다.
  vim의 `hjkl`은 홈로우 일직선이지만 위/아래(`k`/`j`)에 공간적 근거가 없다.
- **`wasd`**: 게임 배치 그대로라 역시 외울 게 없고, 왼손이 통째로 비어 있었다.
- **등속 이동**: Karabiner의 `mouse_key`에는 가속 곡선이 없어서 누르는 내내 같은 속도다
  (`3000`, 저속은 `500`). NixOS 쪽에는 램프가 있었지만 이 제약에 맞춰 걷어냈다 — 같은
  레이어가 머신마다 다르게 구는 값을 치를 만큼 편하지 않았다는 게 실사용 결론이다.
  전체 배율은 프로파일의 `mouse_key_xy_scale`로도 조정할 수 있다.
- **조합은 없다**: 이 레이어는 단발 키만 보낸다. `d2w`나 `ci"` 같은 조합은 키 입력을
  *언어*로 파싱하는 애플리케이션(=에디터)이 있어야 성립하므로, OS 레벨 레이어의 천장은
  어차피 평평한 키 표다. 자세한 논의는 `keyboard.nix.vim` 헤더 참고.
- **규칙 순서 의존성**: Karabiner는 매니퓰레이터를 위에서 아래로 평가하고 처음 매칭되는
  규칙이 발동한다. 그래서 `⇧wasd`/`⇧q`/`⇧e` 규칙을 기본 규칙보다 **위에** 두었다.
- **`⌘←/→` 앱 의존성**: 줄 처음/끝은 표준 macOS 텍스트뷰 기준이다. 터미널이나 일부 앱은
  다르게 처리할 수 있다.
- **실기 확인 필요**: 리눅스에서 검증할 수 없었던 게 둘이다. (1) `vertical_wheel` /
  `horizontal_wheel`의 부호 방향 — `q`가 아래로 스크롤되면 `q`/`e`의 부호를 맞바꾼다.
  (2) 포인터 속도는 실기에서 맞췄다. NixOS 쪽 700/100 px/s와 숫자를 맞췄던 초기값
  `700`/`100`은 macOS에서 체감이 너무 느려, 실기에서 올려 `3000`/`500`으로 확정했다.
  Karabiner의 단위는 Retina 포인트 환산을 거치므로 두 OS의 숫자가 갈리는 건 정상이다.

## 마우스 휠 방향은 여기서 안 한다

Karabiner 에는 장치별로 휠을 뒤집는 `devices[].mouse_flip_vertical_wheel` 이 있고, 실제로
동작한다 (2026-08-18 에 G102 로 확인). 그런데도 이 파일에 안 두는 이유는 **"트랙패드가
아닌 모든 마우스"를 표현할 수 없어서**다. 두 겹으로 막힌다:

1. `devices` 항목의 식별자 대조는 완전 일치다 — `profile.hpp` 가
   `d->get_identifiers() == identifiers` 로 찾는다. vendor/product 를 뺀
   `{"is_pointing_device": true}` 는 "모든 포인팅 장치"가 아니라 *식별자가 정확히
   그것뿐인 장치* 를 가리키고, `karabiner_cli --list-connected-devices` 를 보면 하필
   그게 내장 트랙패드다. 원하는 것의 정반대만 적힌다.
2. 복합 수정의 `mouse_basic` (`"flip": ["vertical_wheel"]`) 에 `device_unless` 를 붙여
   규칙을 일반화해도, flip 은 Karabiner 가 **잡고 있는**(`ignore: false`) 장치에만 걸린다.
   잡으라고 말하는 자리가 결국 `devices` 라서 열거는 그대로 남는다.

전역 스크롤 방향을 끄고 트랙패드만 되뒤집는 반전도 생각해 볼 만하지만(트랙패드는 어느
맥에서나 식별자가 같으니 진짜로 일반적이 된다), 내장 트랙패드에 Modify events 를 켜면
가속·하드웨어 클릭·멀티터치가 통째로 날아간다 —
[pqrs-org/Karabiner-Elements#3409](https://github.com/pqrs-org/Karabiner-Elements/issues/3409).

그래서 이 축은 LinearMouse 가 가져갔다. 장치를 범주(`category: mouse`)로 매칭할 수 있어서
마우스를 몇 개를 꽂든 선언이 한 줄이고, Karabiner 가 포인팅 장치를 잡을 일도 없어진다.
→ [`../linearmouse/README.md`](../linearmouse/README.md)

## 기타 규칙 (레이어와 무관)

- **Won(₩) → 백틱(`` ` ``)**: 한글 입력 소스일 때 `grave_accent_and_tilde` 키를 `⌥` + 백틱으로
  바꿔 백틱 입력을 보장한다.
- **Right Command → F18**: `right_command`를 `f18`로 매핑 (다른 도구의 핫키 트리거용).

## 수정 방법

`~/.config/karabiner/karabiner.json` 을 직접 고친다. 설정 GUI 로 고쳐도 되고, 파일을
열어 고쳐도 된다. Karabiner 가 저장 즉시 리로드하므로 그 자리에서 체감을 본다.
정해졌으면 레포로 되받는다:

```sh
python3 -m json.tool ~/.config/karabiner/karabiner.json > /dev/null   # JSON 유효성
apps/rice-save              # 라이브 → 레포 (축을 안 가리고 전부 훑는다)
git diff                    # 확인하고 커밋
```

**되받기 전에는 이 레포에 아무것도 안 들어간다.** 라이브가 원본이라, 안 하면 다음
머신에는 옛 키맵이 깔린다.

반대 방향(다른 머신에서 온 커밋을 이 머신에 밀어 넣기)은 `apps/rice-restore karabiner`
다. 복원 뒤 유저 서버를 다시 띄우는 것까지 그쪽이 한다.

> 2026-08-06 까지 이 파일은 `modules/darwin/files.nix` 가 거는 읽기 전용 스토어
> 심링크였다. 그래서 여기에는 "심링크를 지우고 → 복사본을 두고 → 다 되면 되돌리고
> build-switch" 라는 우회 절차가 적혀 있었다. 설정 GUI 가 저장할 수 없는 자리에
> 파일을 두었던 것이 원인이고, 지금은 다른 라이싱 파일과 같은 시드 방식이라 그
> 우회가 곧 기본 동작이 되었다.

키를 추가할 때는 아래 형태를 복사해 `key_code`와 `to`만 바꾸면 된다.

```json
{
    "conditions": [
        { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
    ],
    "from": { "key_code": "<키>", "modifiers": { "optional": ["any"] } },
    "to": [{ "key_code": "<대상>", "modifiers": ["<수식키>"] }],
    "type": "basic"
}
```

- 이동 계열(Shift로 선택 확장을 허용)은 `"optional": ["any"]`.
- Shift가 통과하면 곤란한 키는 `"optional": ["caps_lock"]` — 왼손 마우스 키가 전부 이쪽이다.
- Shift 조합을 따로 두려면 `"modifiers": { "mandatory": ["shift"], "optional": ["caps_lock"] }`
  규칙을 기본 규칙보다 **위에** 추가한다.
- 포인터는 `"to": [{ "mouse_key": { "x": 1536 } }]`, 버튼은
  `"to": [{ "pointing_button": "button1" }]` (button1/2/3 = 왼쪽/오른쪽/가운데).
