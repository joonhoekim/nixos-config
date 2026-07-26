# Karabiner — Vim/Neovim 네비게이션 레이어

`karabiner.json`의 설정 설명. **Caps Lock을 홀드**하는 동안 키보드를 neovim 노멀모드처럼 쓰는 레이어를 구현한다.

원본은 [TouchCursor](https://github.com/martin-stone/touchcursor) 스타일 설정(스페이스 트리거)이었고, 이를 Caps Lock 트리거 + vim/neovim 키맵으로 재구성했다.

> 원본 touchcursor 버전은 `karabiner.json.touchcursor`에 참조용으로 보관돼 있다. (실제로는 사용하지 않음)

## 트리거 동작 (Caps Lock)

| 입력 | 결과 |
|------|------|
| Caps Lock **탭** (혼자 눌렀다 뗌) | 일반 Caps Lock 토글 |
| Caps Lock **홀드** | 홀드하는 동안 네비게이션 레이어 활성화 (`touchcursor_mode = 1`) |

내부적으로 홀드 시 `touchcursor_mode` 변수를 1로 세팅하고, 뗄 때 0으로 되돌린다. 레이어의 모든 매핑은 이 변수가 1일 때만 발동한다.

> 매핑되지 않은 키는 Caps Lock 홀드 중에도 **그냥 그 글자 그대로** 입력된다. (예전 스페이스 트리거 시절의 `공백+글자` 통과 동작은 제거했다.)

## 키맵 (Caps Lock 홀드 중)

| neovim | 키 | 동작 (macOS) |
|--------|----|------|
| `h` `j` `k` `l` | `h` `j` `k` `l` | ← ↓ ↑ → |
| `w` / `e` | `w` / `e` | 단어 앞으로 (⌥→) |
| `b` | `b` | 단어 뒤로 (⌥←) |
| `0` | `0` | 줄 처음 (⌘←) |
| `$` | `⇧4` | 줄 끝 (⌘→) |
| `{` / `}` | `⇧[` / `⇧]` | 문단 위 / 아래 (⌥↑ / ⌥↓) |
| `gg` / `G` | `g` / `⇧g` | 문서 맨 위 (⌘↑) / 맨 아래 (⌘↓) |
| `/` | `/` | 찾기 (⌘F) |
| `n` / `N` | `n` / `⇧n` | 다음 찾기 (⌘G) / 이전 찾기 (⌘⇧G) |
| `u` | `u` | 실행 취소 (⌘Z) |
| `x` / `X` | `x` / `⇧x` | 앞으로 삭제 (Del) / 뒤로 삭제 (Backspace) |
| `y` | `y` | 복사 (⌘C) |
| `p` | `p` | 붙여넣기 (⌘V) |

### neovim에 순수 대응이 없어 편의상 추가한 키 (★)

| 키 | 동작 | 비고 |
|----|------|------|
| `i` | PageUp | neovim `i`는 insert 진입이라 OS 대응 없음. Ctrl-b/Ctrl-u 대체 |
| `m` | PageDown | neovim `m`은 mark라 OS 대응 없음. Ctrl-f/Ctrl-d 대체 |
| `⇧u` | 다시 실행 (⌘⇧Z) | neovim redo는 `Ctrl-r`이라 이 레이어엔 대응 키가 없음 |

## Shift 조합

- **이동 계열**(`h j k l`, `w e b`, `0`, `i`, `m`)은 Shift를 함께 누르면 **선택 확장**된다. 예) `Caps+⇧j` = 아래로 선택, `Caps+⇧w` = 단어 선택.
- 단, **Shift 자체가 커맨드인 키**(`$`=⇧4, `{`/`}`=⇧[/⇧], `G`=⇧g, `N`=⇧n, `X`=⇧x, `U`=⇧u)는 Shift가 그 커맨드를 발동하므로 선택 확장에는 쓰이지 않는다.

## 설계 노트

- **홈로우 vim 화살표**: `hjkl`을 홈로우에 두고, 위쪽 `i`=PageUp / 아래쪽 `m`=PageDown으로 위·아래 직관을 유지.
- **매핑 제외**: neovim 노멀모드 키 중 macOS 단일 키 대응이 없는 것(`a c d f s r t v q z o` 등 insert 진입 · compound · char-search)은 레이어에 넣지 않았다. 홀드 중 눌러도 원래 글자로 입력된다.
- **규칙 순서 의존성**: Karabiner는 매니퓰레이터를 위에서 아래로 평가하고 처음 매칭되는 규칙이 발동한다. 그래서 대문자 커맨드(`N` `G` `X` `U`, `$`)를 각각의 소문자 규칙보다 **위에** 배치해, Shift가 눌린 경우 먼저 잡히도록 했다.
- **`$` / 문단 이동 앱 의존성**: 줄 끝(⌘→)·문단 이동(⌥↑/⌥↓)은 표준 macOS 텍스트뷰에서 동작하며, 일부 앱은 문단 단위를 지원하지 않을 수 있다.

## 기타 규칙 (레이어와 무관)

- **Won(₩) → 백틱(`` ` ``)**: 한글 입력 소스일 때 `grave_accent_and_tilde` 키를 `⌥` + 백틱으로 바꿔 백틱 입력을 보장한다.
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
- 커맨드 계열(`⌘C` 등, Shift 통과를 막고 싶을 때)은 `"optional": ["caps_lock"]`.
- 대문자 커맨드를 따로 두려면 `"modifiers": { "mandatory": ["shift"], "optional": ["caps_lock"] }` 규칙을 소문자 규칙보다 **위에** 추가한다.
