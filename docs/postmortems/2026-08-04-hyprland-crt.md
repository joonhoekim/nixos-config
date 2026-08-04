# 2026-08-04 — 전역 CRT 셰이더: 축이 둘인데 하나로 묶어 뒀다

환경: NixOS 26.11, Hyprland 0.56.1 (uwsm), DMS 1.5.3, mn56 (Ryzen 7 7840HS / 780M),
DP-1 2560x1440@59.95 + HDMI-A-1 1920x1080@60 (transform=1).

"전역 셰이더가 매우 불안정하다"로 시작했다. 증상은 하나로 보였는데 원인이 둘이었고,
둘 다 같은 착각에서 나왔다 — **`decoration:screen_shader` 에 딸려 오는 하이프랜드
옵션이 하나뿐이라고 생각한 것.**

---

## 증상

1. 창을 드래그하면 둘레에 잔상이 남고, 스캔라인 세기가 사각형 모양으로 갈린다.
2. `crt-motion.frag` 의 험 바가 **마우스나 키보드를 건드릴 때만** 한 칸씩 흐른다.

두 모니터 모두에서 똑같이 났다. 회전(transform=1)은 무관했다.

---

## 원인 1 — `debug:damage_tracking` 의 판정 기준이 틀렸다

`apps/rice-crt` 와 `hyprland.lua` 가 같은 규칙을 쓰고 있었다.

```sh
# 셰이더 파일이 `uniform float time` 을 쓰면 → damage_tracking = 0, 아니면 → 2
grep -Eq '^[[:space:]]*uniform[[:space:]]+float[[:space:]]+time[[:space:]]*;' "$src"
```

`crt.frag` 에는 `time` 이 없으니 `2`(세밀한 트래킹)로 돌았다. 그런데 **`time` 유무는
잘못된 시험지다.** 데미지 트래킹을 깨뜨리는 조건은 이것이다:

> 셰이더가 **자기 픽셀 밖을 읽는가.**

`crt.frag` 는 셋이나 읽는다.

| 함수 | 얼마나 멀리 |
|---|---|
| `curve()` | 배럴 왜곡 — 가장자리에서 수십 px 어긋난 지점 |
| `gun()` | 색수차 ±3 px, 초점 탭 ±0.8 px |
| `bloom()` | 5 px 반경에 16 탭 |

하이프랜드는 **바뀐 사각형만** 다시 합성하는데 셰이더는 그 사각형 *바깥*을 읽는다.
사각형 안에서는 이미 바뀐 이웃을 낡은 값으로 읽고, 사각형 밖에서는 이웃이 바뀌었는데
다시 안 그려져 낡은 결과가 남는다 — 증상 1 의 잔상이다. 여기에 `stripes()` 의
`fwidth()` 는 미분값이라 사각형 경계에서 불연속이 되고, 그게 스캔라인 세기가 사각형
모양으로 갈리던 이음매다.

`time` 을 쓰는 셰이더가 트래킹을 꺼야 하는 건 맞다(하이프랜드가 직접 그렇게 말한다).
틀린 건 **그 역**을 참이라고 본 것이다.

---

## 원인 2 — `debug:vfr` 이라는 축을 아예 안 다루고 있었다

증상 2 는 트래킹을 아무리 내려도 안 없어졌다. 다른 축이기 때문이다.

| 옵션 | 정하는 것 |
|---|---|
| `debug:damage_tracking` | 프레임을 그릴 때 **어디를** 그리는가 |
| `debug:vfr` | 프레임을 **그릴지 말지** |

VFR 이 켜져 있으면(기본값) 하이프랜드는 화면에 바뀐 것이 없을 때 **프레임을 아예 안
그린다.** `time` 은 그리는 순간에만 진행하므로, 입력이 있어야 험 바가 한 칸 움직인다.
`damage_tracking = 0` 은 "그릴 때 전체를 그려라"일 뿐 "그려라"가 아니다.

레포 주석은 정확히 이 지점을 반대로 적고 있었다. `crt-motion.frag` 와 `rice-crt`
양쪽에 같은 문장이 있었다:

> `damage_tracking = 0` … 그 순간부터 화면은 아무것도 안 바뀌어도 **매 프레임 통째로
> 다시 그려져서** 배터리가 눈에 띄게 준다

아니다. VFR 이 남아 있으면 아무것도 안 바뀔 때 **안 그린다.** 두려워하던 배터리
비용은 `damage_tracking` 이 아니라 `debug:vfr` 에 붙어 있었고, 정작 그 옵션은 이
저장소가 한 번도 건드린 적이 없었다.

하이프랜드 자신의 경고 두 줄이 이 착각을 거들었다 — 붙어 있으니 한 원인으로 읽힌다.

```
Screen shader uses uniform '{}', which requires debug:damage_tracking to be switched off.
WARNING:(Disabling damage tracking will *massively* increase GPU utilization!
```

두 번째 줄의 "massively" 는 VFR 이 꺼져 있을 때만 맞다.

---

## 실측 표

이 표가 결론이다. 다섯 조합을 눈으로 확인했다.

| 셰이더 | damage | vfr | 결과 |
|---|---|---|---|
| `crt.frag` | 2 | 켬 | **잔상 + 이음매** (원래 설정) |
| `crt.frag` | 1 | 켬 | 나아졌지만 잔상 남음 |
| `crt.frag` | **0** | **켬** | **깨끗** |
| `crt-motion.frag` | 0 | 켬 | 깨끗하지만 애니메이션이 입력에만 반응 |
| `crt-motion.frag` | **0** | **끔** | **깨끗 + 연속 애니메이션** |

두 축이 서로 다른 조건에 묶인다는 게 표에 그대로 나온다.

- `damage_tracking` → **셰이더가 걸렸는가** (이웃을 읽으니까). `time` 과 무관.
- `vfr` → **`time` 을 쓰는가**. 정지 셰이더는 켜 둔 채가 맞다.

`time` grep 은 살아남았다. 옳은 시험지였는데 **엉뚱한 손잡이에 묶여 있었을 뿐**이다.

---

## 고침

`apps/rice-crt` 와 `modules/nixos/hyprland/rice/hyprland.lua` 가 같은 행렬을 쓴다.

| | `damage_tracking` | `vfr` |
|---|---|---|
| off | 2 (기본) | true |
| `crt.frag` | 0 | true |
| `crt-motion.frag` | 0 | false |

`hyprland.lua` 에는 `apply_crt()` 하나를 두고 시작 시점과 `Mod+Shift+C` 가 같이
쓴다. 로그인 직후부터 걸리게 바꿨다 — 이 룩을 켜는 건 비용을 알고 켜는 것이라,
기기별로(노트북이라고) 가르지 않는다.

**주의.** `hyprland.lua` 를 저장할 때마다 `apply_crt` 가 다시 돌아서, off 로 둔 채
그 파일을 고치면 도로 켜진다. 값을 맞춰 가는 중이라면 `apps/rice-crt --reload` 를
쓴다(그쪽은 걸린 것을 그대로 다시 읽는다).

---

## 다음에 빨리 잡는 법

```sh
# 1. 지금 걸린 세 값. 셰이더만 보고 판단하지 않는다 — 축이 셋이다
hyprctl getoption decoration:screen_shader
hyprctl getoption debug:damage_tracking     # 0 없음 / 1 모니터 / 2 full(기본)
hyprctl getoption debug:vfr                 # true 면 놀 때 프레임을 안 그린다

# 2. 증상으로 축을 가른다
#    잔상·이음매가 움직이는 것 둘레에      → damage_tracking
#    애니메이션이 입력에만 반응            → vfr

# 3. 옵션 이름이 안 맞을 때. `misc:vfr` 은 없다("no such option") — `debug:vfr` 이다.
#    bin/Hyprland 는 bash 래퍼라 strings 가 26 줄밖에 안 나온다. 진짜 ELF 는 이쪽:
strings /nix/store/*-hyprland-*/bin/.Hyprland-wrapped | grep -E '^(misc|debug|render):[a-z_]+$' | sort -u
```

---

## 배울 것

**붙어 있는 두 옵션이 한 원인은 아니다.** 하이프랜드의 경고가 damage_tracking 과 GPU
사용량을 한 문단에 적어 놨고, 그래서 "트래킹을 끄면 계속 그린다"로 읽혔다. 실제로는
그리는 양(damage)과 그리는 횟수(vfr)가 따로였다. 옵션 둘이 같은 증상을 낸다고 느껴지면
**각각을 따로 움직여 보는 표**를 먼저 만든다 — 위의 다섯 줄이 조사의 전부였다.

**규칙의 시험지가 옳아도 손잡이가 틀릴 수 있다.** `time` grep 은 처음부터 정확했다.
잘못된 건 그 결과를 `damage_tracking` 에 연결한 것이고, 그래서 "왜 이 판정이 있는가"를
다시 물을 때까지 아무도 grep 자체를 의심하지 않았다. 조건문을 볼 때 조건과 결론을
따로 검산한다.

**주석은 검증되지 않은 채로 오래 산다.** "매 프레임 통째로 다시 그려진다"는 문장은
두 파일에 있었고 둘 다 틀렸다. 한 번도 재 본 적이 없어서 그렇다. 비용을 주장하는
주석에는 **어떻게 재는지**를 같이 적는 편이 낫다.
