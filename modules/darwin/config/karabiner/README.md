# Karabiner — TouchCursor 네비게이션 레이어

`karabiner.json`의 설정 설명. **Caps Lock을 홀드**하는 동안 홈로우를 떠나지 않고 커서를
움직이는 레이어를 구현한다. 배치는 [TouchCursor](https://github.com/martin-stone/touchcursor)와
같고, 트리거만 기본값(스페이스) 대신 Caps Lock이다 — 윈도우 머신의 TouchCursor에서도
기본 설정에서 이것 하나만 바꿔 쓰기 때문에, 세 OS가 같은 손가락 기억을 공유한다.

NixOS 쪽은 같은 배치를 keyd로 구현한다: [`modules/nixos/keyboard.nix`](../../../nixos/keyboard.nix).

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

## 키맵 (Caps Lock 홀드 중)

| 키 | 동작 (macOS) | | 키 | 동작 (macOS) |
|----|------|-|----|------|
| `i` `j` `k` `l` | ↑ ← ↓ → (역T) | | `w` / `e` | 단어 앞으로 (⌥→) |
| `u` / `o` | 줄 처음 / 끝 (⌘← / ⌘→) | | `b` | 단어 뒤로 (⌥←) |
| `h` / `n` | PageUp / PageDown | | `g` / `⇧g` | 문서 맨 위 / 맨 아래 (⌘↑ / ⌘↓) |
| `p` / `m` | 뒤로 / 앞으로 삭제 | | `/` | 찾기 (⌘F) |
| `y` | Insert | | | |

오른쪽 열은 TouchCursor에 대응이 없어 vim에서 빌려온 것들이다. TouchCursor가 비워두는
키에만 얹었으므로 원래 배치와 충돌하지 않는다.

## Shift 조합

**모든 바인딩이 unshifted**라서 Shift는 커맨드의 일부가 되는 일이 없고, 통째로 **선택
확장**에 쓸 수 있다. `Caps+⇧j` = 왼쪽으로 선택, `Caps+⇧o` = 줄 끝까지 선택.

유일한 예외가 `⇧g`(문서 맨 아래)이고, 그래서 그것만 선택이 아니라 이동으로 나간다. 예전
vim 배치는 `$ { } G N X U`가 전부 이런 상태였다.

## 설계 노트

- **역T 화살표**: `ijkl`은 물리 화살표 클러스터와 모양이 같아서 방향을 외울 게 없다.
  vim의 `hjkl`은 홈로우 일직선이지만 위/아래(`k`/`j`)에 공간적 근거가 없다.
- **조합은 없다**: 이 레이어는 단발 키만 보낸다. `d2w`나 `ci"` 같은 조합은 키 입력을
  *언어*로 파싱하는 애플리케이션(=에디터)이 있어야 성립하므로, OS 레벨 레이어의 천장은
  어차피 평평한 키 표다. 자세한 논의는 `keyboard.nix.vim` 헤더 참고.
- **규칙 순서 의존성**: Karabiner는 매니퓰레이터를 위에서 아래로 평가하고 처음 매칭되는
  규칙이 발동한다. 그래서 `⇧g` 규칙을 `g` 규칙보다 **위에** 두었다.
- **`⌘←/→` 앱 의존성**: 줄 처음/끝은 표준 macOS 텍스트뷰 기준이다. 터미널이나 일부 앱은
  다르게 처리할 수 있다.

## 기타 규칙 (레이어와 무관)

- **Won(₩) → 백틱(`` ` ``)**: 한글 입력 소스일 때 `grave_accent_and_tilde` 키를 `⌥` + 백틱으로
  바꿔 백틱 입력을 보장한다.
- **Right Command → F18**: `right_command`를 `f18`로 매핑 (다른 도구의 핫키 트리거용).

## 수정 방법

1. `karabiner.json`을 편집한다.
2. JSON 유효성 확인: `python3 -m json.tool karabiner.json > /dev/null`
3. darwin/home-manager 리빌드로 `~/.config/karabiner/karabiner.json`에 배포한다.
4. Karabiner-Elements가 파일 변경을 감지해 자동 리로드한다. (안 되면 앱에서 프로파일 재선택)

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
- Shift가 통과하면 곤란한 키는 `"optional": ["caps_lock"]`.
- Shift 조합을 따로 두려면 `"modifiers": { "mandatory": ["shift"], "optional": ["caps_lock"] }`
  규칙을 기본 규칙보다 **위에** 추가한다.
