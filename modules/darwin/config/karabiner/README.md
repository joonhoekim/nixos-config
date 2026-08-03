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

## 기타 규칙 (레이어와 무관)

- **Won(₩) → 백틱(`` ` ``)**: 한글 입력 소스일 때 `grave_accent_and_tilde` 키를 `⌥` + 백틱으로
  바꿔 백틱 입력을 보장한다.
- **Right Command → F18**: `right_command`를 `f18`로 매핑 (다른 도구의 핫키 트리거용).

## 수정 방법

1. `karabiner.json`을 편집한다.
2. JSON 유효성 확인: `python3 -m json.tool karabiner.json > /dev/null`
3. darwin/home-manager 리빌드로 `~/.config/karabiner/karabiner.json`에 배포한다.
4. Karabiner-Elements가 파일 변경을 감지해 자동 리로드한다. (안 되면 앱에서 프로파일 재선택)

값을 여러 번 시험해야 할 때는 리빌드를 돌릴 필요가 없다. 심링크를 걷어내고 복사본을 두면
Karabiner가 저장 즉시 리로드하므로, 그 자리에서 숫자만 바꿔 가며 체감을 볼 수 있다.

```sh
rm ~/.config/karabiner/karabiner.json          # nix store 심링크 제거
cp karabiner.json ~/.config/karabiner/         # 쓰기 가능한 복사본
chmod u+w ~/.config/karabiner/karabiner.json
# ...편집·체감 반복. 정해지면 이 리포 파일에 값을 옮기고
rm ~/.config/karabiner/karabiner.json && build-switch   # 심링크 원상복구
```

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
