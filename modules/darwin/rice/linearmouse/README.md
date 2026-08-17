# LinearMouse — 트랙패드는 그대로, 마우스 휠만 뒤집기

macOS 의 "자연스러운 스크롤"은 전역 스위치 **하나**다. 트랙패드에 맞춰 켜 두면 마우스 휠도
같이 뒤집혀서 다른 OS 와 손이 갈리고, 시스템 설정만으로는 둘을 갈라 놓을 방법이 없다.

`linearmouse.json` 이 그 하나를 둘로 가른다:

```json
{
  "schemes": [
    { "if": { "device": { "category": "mouse" } },
      "scrolling": { "reverse": { "vertical": true } } }
  ]
}
```

시스템 설정의 자연스러운 스크롤은 **켠 채로 둔다.** 이 파일은 그 위에서 마우스만 되돌리는
차분이라, 끄면 마우스가 두 번 뒤집혀 도로 어색해진다.

## 왜 Karabiner 가 아닌가

Karabiner 에도 같은 기능이 있고(`devices[].mouse_flip_vertical_wheel`) 실제로 동작한다.
`category` 하나가 이유의 전부다 — Karabiner 쪽은 마우스를 **하나씩 vendor/product 로
열거**해야 하고, 여기는 "마우스면 전부"가 한 줄이다. 새 마우스를 꽂아도 할 일이 없다.

덤으로 Karabiner 가 포인팅 장치를 잡지 않아도 되므로(잡으면 포인터 이동까지 가상 HID 를
거치고 CPU 도 그만큼 쓴다) 마우스 경로가 그대로다. 막힌 지점의 자세한 근거는
[`../karabiner/README.md`](../karabiner/README.md) 의 "마우스 휠 방향은 여기서 안 한다".

## 설정 파일

`~/.config/linearmouse/linearmouse.json`. 다른 라이싱 파일과 같은 시드 방식이라
(`modules/darwin/rice/default.nix`) **없을 때만** 심긴다 — 설정 GUI 가 이 파일에 직접 쓰기
때문에, 스토어 심링크로 두면 GUI 저장이 조용히 실패한다.

시드가 "없을 때만"이라는 게 여기서는 순서 문제를 하나 만든다: LinearMouse 는 처음 실행될
때 설정이 없으면 **빈 설정을 스스로 만든다.** build-switch 보다 앱을 먼저 띄웠다면 그 빈
파일이 이미 있어서 시드가 비켜 간다. 그때는 지우고 다시 심으면 된다:

```sh
rm ~/.config/linearmouse/linearmouse.json
apps/rice-restore linearmouse
```

고치는 방향은 다른 축과 같다. 라이브를 고치고(설정 GUI 로 하든 파일을 열든) 체감을 본 뒤
레포로 되받는다:

```sh
python3 -m json.tool ~/.config/linearmouse/linearmouse.json > /dev/null   # JSON 유효성
apps/rice-save              # 라이브 → 레포
```

JSON5 가 아니라 **주석을 쓰면 파싱 에러**다. 설명은 이 파일에 적는다.

`$schema` 는 버전이 박힌 URL(`https://schema.linearmouse.app/0.11.4`)이다. 앱을 올린 뒤
새 키를 쓰려면 그 숫자도 같이 올린다 — 스키마는 에디터 보조일 뿐이라 안 맞아도 앱은 돈다.

> 그 스키마를 볼 때 `examples` 블록은 믿지 말 것. 0.11.4 의 것에는
> `"reverse": "vertical"` 이라고 적혀 있는데 앱은 이걸 거부한다
> (`Type mismatch: expected Bool at schemes.Index 0.scrolling.reverse`).
> 정의부는 `boolean` 아니면 `{ "horizontal": bool, "vertical": bool }` 이고, 예제 쪽이
> 검증을 안 받는 자리라 그대로 썩어 있다. `definitions` 를 보고 쓴다.
>
> 그리고 이 앱은 **설정을 통째로 거부한다** — 한 키가 틀리면 그 scheme 만 빠지는 게
> 아니라 파일 전체가 안 먹는다. 고친 뒤에는 아래 kickstart 로 다시 읽히고 메뉴바
> 아이콘에 에러가 없는지 본다.
>
> ```sh
> launchctl kickstart -k "gui/$(id -u)/org.nixos.linearmouse"
> ```

## 로그인 실행

`hosts/darwin/default.nix` 의 `launchd.user.agents.linearmouse`. stats · WorkspacePeek 과
같은 모양이다 — 앱 자체의 "Start at login" 토글은 앱이 자기 설정에서 다시 쓰는
SMAppService 로그인 항목이라, 이 레포가 선언적으로 들고 있는 것과 어긋난다.

첫 실행에서 **입력 모니터링** 권한을 한 번 요구한다. 거부하면 앱은 멀쩡히 떠 있는 채로
아무 일도 안 한다(휠 방향이 안 바뀌는 것 말고는 증상이 없다). 시스템 설정 → 개인정보
보호 및 보안 → 입력 모니터링에서 켜면 된다.

## 여기서 안 하는 것

포인터 가속(`pointer.acceleration`)과 스크롤 속도도 이 앱의 영역이지만 건드리지 않았다.
지금 요구사항은 방향 하나뿐이고, 가속까지 이 파일이 가져가면 시스템 설정의 마우스 슬라이더가
"보이는데 안 듣는" 상태가 된다. 필요해지면 그때 같은 scheme 에 키를 더한다.
