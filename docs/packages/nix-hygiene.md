# Nix 저장소 위생

**이 저장소 자체를 고칠 때** 쓰는 도구 모음 — 린트, 빌드 관찰, 세대 비교, 용량
추적. 선언은 `modules/shared/packages.nix`의 "Nix tooling" 절에 있다.

---

## 왜 따로 필요한가

`.nix` 파일에는 다른 언어에 있는 안전망이 없다. 테스트가 없고, 타입 검사가 없고,
문법이 맞으면 대부분 그냥 평가된다. 잘못된 곳은 **rebuild가 실패할 때**나
**바뀌지 않아야 할 것이 바뀌었을 때** 드러나는데, 둘 다 늦다.

여기 있는 도구들이 그 간격을 메운다.

| 시점 | 도구 | 답하는 질문 |
|---|---|---|
| 고치는 중 | `nil` / `nixd` | 이 이름이 존재하나 (LSP) |
| 고친 직후 | `nixfmt` | 모양이 일관된가 |
| 고친 직후 | `statix` | 이 표현이 안티패턴인가 |
| 고친 직후 | `deadnix` | 안 쓰이는 바인딩이 남았나 |
| 빌드 중 | `nom` | 지금 무엇을 빌드하고 있나 |
| 빌드 후 | `nvd` | 실제로 무엇이 바뀌었나 |
| 수시 | `nix-tree` | 이 용량은 어디서 왔나 |

**`statix`와 `deadnix`는 종료코드로 판정된다.** `.nix`를 고친 뒤 스스로 검증할
수단이 그동안 `nixfmt`뿐이었는데(모양만 본다), 이 둘이 내용 쪽을 맡는다 — 사람도
쓰지만 **에이전트가 자기 편집을 확인하는 데 특히 값어치가 있다.**

---

## statix — 안티패턴

```sh
statix check .              # 저장소 전체
statix check modules/       # 일부만
statix fix .                # 고칠 수 있는 것은 고친다
statix explain W20          # 이 경고가 무슨 뜻인지
```

이 저장소에서 실제로 걸리는 것들:

| 코드 | 잡는 것 |
|---|---|
| `W03` | `a = a;` → `inherit a;` |
| `W04` | `a = someAttr.a;` → `inherit (someAttr) a;` |
| `W10` | 빈 가변 패턴 `{ ... }:` → `_:` |
| `W20` | 키가 반복되는 어트리뷰트 셋 → 중첩으로 접기 |

전체 목록과 각 코드의 근거는 `statix explain W04`처럼 물어보면 나온다.

무시는 `statix.toml`에 린트 이름으로 적는다 (코드가 아니다).

```toml
disabled = ["empty_pattern"]
```

> `statix fix`는 파일을 제자리에서 바꾼다. 커밋되지 않은 변경 위에 돌리기 전에
> `statix check`로 무엇이 바뀔지 먼저 볼 것.

---

## deadnix — 죽은 바인딩

```sh
deadnix .                   # 보고만
deadnix -e .                # 고친다 (--edit)
deadnix --no-lambda-arg .   # 함수 인자는 빼고 — 오탐이 많은 쪽이다
```

`let` 안에 남은 바인딩이나 쓰이지 않는 함수 인자를 찾는다. 모듈 시그니처의
`{ config, pkgs, lib, ... }`처럼 **관례상 받아 두는 인자**를 잡아내므로,
`--no-lambda-arg` 없이 `-e`를 돌리면 멀쩡한 모듈 헤더가 깎인다.

무시는 주석으로 단다: `# deadnix: skip`.

---

## nom — 빌드가 지금 무엇을 하고 있나

`nix build`의 기본 출력은 마지막 몇 줄만 보여줘서, 오래 걸릴 때 **멈춘 것인지
큰 것을 빌드하는 중인지** 구분이 안 된다. `nom`은 같은 로그를 트리로 그린다.

```sh
nix build .#nixosConfigurations.mn56.config.system.build.toplevel --log-format internal-json 2>&1 | nom --json

# 짧게 쓰는 래퍼도 있다
nom build .#…
nom-shell / nom-build      # nix-build / nix-shell 대응
```

---

## nvd — 스위치가 실제로 바꾼 것

이 묶음에서 가장 자주 손이 갈 물건이다. `apps/build-switch`는 새 세대를
활성화하고 "complete"만 찍는다. **무엇이 달라졌는지는 말해주지 않는다.**

```sh
# 마지막 두 세대 비교 (NixOS)
nvd diff $(ls -dv /nix/var/nix/profiles/system-*-link | tail -2)
```

`ls -dv`의 `-v`가 필요하다 — 사전순으로 정렬하면 `system-9-link`가
`system-10-link`보다 뒤로 간다.

출력은 추가(`[A+]`)·삭제(`[R-]`)·버전 변경(`[U*]`)으로 갈린다. **nixpkgs를
업데이트한 뒤 "이 커밋이 무엇을 건드렸나"에 답하는 유일한 수단**이고, 무언가
망가졌을 때 범인 후보를 좁히는 출발점이다.

빌드하되 활성화하기 전에 미리 보는 쪽이 더 안전하다.

```sh
nix build .#nixosConfigurations.mn56.config.system.build.toplevel
nvd diff /run/current-system ./result
```

---

## nh — 위의 것들을 묶은 래퍼

`nh`는 rebuild를 `nom` 출력으로 돌리고 끝나면 `nvd` diff를 자동으로 보여준다.

```sh
nh os build .            # 빌드만 (활성화 없음)
nh os switch .           # 빌드 + 활성화 + diff
nh darwin switch .       # macOS
nh clean all --keep 5    # 오래된 세대 정리
```

**이 저장소의 정본 절차는 여전히 `nix run .#build-switch`다.** `apps/build-switch`
는 sudo를 활성화 단계에만 거는 방식과 `--host` 오버라이드를 들고 있고, `nh`는
그 두 가지를 모르기 때문이다. `nh`는 "지금 이 변경이 무엇을 바꾸는지 보면서
반복해서 돌려 볼 때" 쓰는 보조 수단으로 둔다.

---

## nix-tree — 용량이 어디서 왔나

```sh
nix-tree /run/current-system         # 지금 시스템의 클로저
nix-tree ./result
nix-tree --derivation .#foo
```

TUI에서 `w`를 누르면 **왜 이것이 들어와 있는지**(역참조 경로)를 보여준다.
"이 패키지 하나가 2GB를 끌고 왔다"를 확인하는 자리다.

숫자만 빠르게 볼 때는 nix 내장으로 충분하다.

```sh
nix path-info -Sh /run/current-system            # 클로저 전체 크기
du -sh /nix/store                                 # 스토어 전체
```

---

## 한 번에 돌리기

```sh
nixfmt $(fd -e nix) && statix check . && deadnix --no-lambda-arg .
```

셋 다 종료코드로 판정되므로 훅이나 CI에 그대로 물린다
([`security-hygiene.md`](security-hygiene.md)의 `lefthook` 절).

---

## 함정

**`statix fix`와 `deadnix -e`는 파일을 바꾼다.** 커밋되지 않은 변경 위에서
돌리면 무엇이 내 편집이고 무엇이 도구의 편집인지 섞인다. 커밋한 뒤에 돌리고
따로 커밋하는 편이 낫다 (AGENTS.md의 "한 커밋은 한 가지 일만 한다").

**`deadnix`의 기본 설정은 모듈 헤더를 깎는다.** `{ config, pkgs, lib, ... }`에서
안 쓰는 인자를 지우면 당장은 평가되지만, 나중에 그 인자를 쓰려 할 때 다시
추가해야 한다. `--no-lambda-arg`를 기본으로 쓸 것.

**`nvd`는 세대 두 개가 있어야 한다.** 첫 스위치 뒤에는 비교 대상이 없다.

---

## 안 넣은 것과 이유

- **`nix-du` / `nix-visualize`** — `nix-tree`와 자리가 겹친다. 그래프 이미지를
  뽑는 쪽이 필요해지면 재검토.
- **`cachix`** — 바이너리 캐시를 **제공**하는 쪽 도구다. 이 저장소는 공개 캐시를
  소비하기만 하고 직접 푸시하지 않는다.
- **`nix-init` / `nurl`** — 새 패키지 표현식을 만들어 주는 도구. 이 저장소가
  하는 일은 `overlays/`에서 기존 패키지를 덮는 쪽이라 자리가 다르다.
- **`nixpkgs-fmt` / `alejandra`** — 포매터가 둘이면 파일이 왔다 갔다 한다.
  `nixfmt`(RFC 스타일)가 정본이다.

---

## 관련 문서

- [`README.md`](README.md) — 이 디렉토리(도구 안내서)의 인덱스
- [`../02-this-repo.md`](../02-this-repo.md) — 선언이 어느 파일로 흘러가는지
- [`../03-operating-on-macos.md`](../03-operating-on-macos.md) — 패키지를 더한 뒤의 반영 절차
