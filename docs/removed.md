# 지운 것들

레포에서 걷어낸 설정과, 되살릴 때 필요한 커밋을 적는다. 한 대상은 한 커밋으로
지웠으므로 그 커밋 하나만 되돌리면 된다.

되살리는 방법은 두 가지다.

```sh
git revert <sha>                         # 지운 커밋을 통째로 되돌린다
git checkout <sha>~1 -- <경로>...          # 특정 파일만 지우기 직전 상태로 꺼낸다
```

`revert` 는 그 뒤에 같은 자리를 고친 커밋이 있으면 충돌한다. 그때는 파일만 꺼내는
쪽이 낫다. 커밋에서 무엇이 빠졌는지는 `git show --stat <sha>` 로 본다.

SHA 는 `cleanup` 브랜치를 main 에 fast-forward 로 합친다는 전제의 값이다. rebase·
squash 로 합치면 바뀌므로 이 표도 다시 적는다.

## Karabiner-Elements 설정

| | |
|---|---|
| 커밋 | `65cc5bb` chore(darwin): 쓰지 않는 Karabiner-Elements 설정을 지운다 |
| 대상 | `modules/darwin/deprecated/karabiner/` (`karabiner.json`, `.touchcursor`·`.vim` 보관본, README) |
| 대체 | `modules/shared/kanata/` — 같은 Caps Lock 레이어 |
| 뒤따른 커밋 | `cd6e8ee` — rift 설정의 Karabiner-Elements 플로팅 규칙 |

어디에서도 로드되지 않던 보관본이다. 되살려도 kanata 와 같이 돌릴 수 없다 — 둘 다
키보드를 독점으로 잡고, Karabiner-Elements 가 까는 드라이버 데몬의 판이 kanata 가
아는 판과 다르다(`modules/darwin/kanata.nix` 머리말). 돌아가려면 kanata 데몬을 끄고
`karabiner-elements` cask 를 넣은 뒤 `karabiner.json` 을 `~/.config/karabiner/` 에 둔다.

## AeroSpace

| | |
|---|---|
| 커밋 | `12a179d` chore(darwin): 폴백으로 남겨 둔 AeroSpace 를 지운다 |
| 대상 | `aerospace` cask, `nikitabobko-tap` flake input, `modules/darwin/rice/aerospace/aerospace.toml` 과 그 시드, `apps/rice/save`·`restore` 의 `aerospace` 항목 |
| 대체 | rift-grid (`apps/rift-grid`, `hosts/darwin/common.nix` 의 `rift` 에이전트) |

로그인에 뜨지 않고 `open -a AeroSpace` 로만 쓰던 폴백이다. 되살린 뒤에는:

- `nix flake lock` — `nikitabobko-tap` 이 lock 에 다시 들어간다.
- `hosts/darwin/common.nix` 의 `spaces.spans-displays` 를 `true` 로. AeroSpace 는
  `true`, rift 는 `false` 를 요구한다. 로그아웃해야 반영된다.
- rift 를 먼저 끈다 — `launchctl bootout gui/$UID/org.nixos.rift-grid`. 두 타일링 WM 이
  같은 창을 잡으면 둘 다 제대로 안 돈다.

## upstream rift 탭

| | |
|---|---|
| 커밋 | `3f53f4a` chore(darwin): upstream rift 로 돌아갈 자리로 남긴 acsandmann 탭을 지운다 |
| 대상 | `acsandmann-tap` flake input 과 nix-homebrew 의 탭 등록 |
| 대체 | rift-grid 포크 |

`modules/darwin/brews.nix` 에 `"acsandmann/tap/rift"` 를 다시 넣을 수 있게 남겨 둔
탭이다(그 파일도 뒤에 지웠다, 아래 brews.nix). `modules/darwin/rice/rift-grid/config.toml` 은 포크에만 있는 명령을 쓰므로
upstream rift 는 그 설정을 읽지 못한다. 되돌리려면 탭과 함께 설정도 포크 이전으로
꺼내야 한다.

## iTerm2

| | |
|---|---|
| 커밋 | `8f488f1` chore(darwin): 쓰지 않는 iTerm2 cask 를 지운다 |
| 대상 | `iterm2` cask |
| 대체 | subline-terminal (주), ghostty·wezterm (참고용) |

## Postman

| | |
|---|---|
| 커밋 | `8cc2438` chore(packages): API 클라이언트를 bruno 하나로 두고 postman 을 지운다 |
| 대상 | macOS `postman` cask, NixOS `postman` 패키지, Windows winget 의 주석 처리된 항목 |
| 대체 | bruno |

## rice 시드의 `unstore`

| | |
|---|---|
| 커밋 | `b3507a6` chore(rice): 스토어 심링크를 시드로 바꿀 때 쓰던 unstore 를 지운다 |
| 대상 | `modules/darwin/rice/default.nix` 의 `unstore()` 와 그 호출, `seedMacRice` 의 `linkGeneration` 순서 의존 |

home-manager 가 걸던 읽기 전용 스토어 심링크를 지워 `rice_sync` 가 시드를 심을 수 있게
하던 일회성 이행 코드다. 스토어 심링크가 남은 기계(2026-08-06 이전 세대에서 바로 올라오는
경우)에서만 의미가 있다.

## home-manager 템플릿 잔재

| | |
|---|---|
| 커밋 | `c3cf4f2` chore(darwin): home-manager.nix 에 남은 템플릿 잔재를 지운다 |
| 대상 | 빈 `homebrew.masApps` 와 mas 안내 주석, `manual.manpages.enable = false` |

manpages 를 끈 것은 home-manager#3344(2022) 우회였다. 다시 빌드가 깨지면 그 한 줄만 되살린다.

## brews.nix

| | |
|---|---|
| 커밋 | `82fc9c2` chore(darwin): 비어 있던 brews.nix 를 지운다 |
| 대상 | `modules/darwin/brews.nix`(빈 목록)와 `home-manager.nix` 의 `brews = ...` 줄 |

`"acsandmann/tap/rift"` 한 줄을 두려고 2026-08-05 에 만든 파일이다. rift-grid 로 옮기며
비었고, upstream rift 탭을 지우면서 남겨 둘 이유가 없어졌다. formula 가 필요해지면 파일을
되살릴 필요 없이 `homebrew.brews = [ ... ];` 를 쓴다.

## 레포 밖에 남는 것

`homebrew.onActivation.cleanup` 이 꺼져 있어서 목록에서 빼도 이미 깔린 것은 지워지지
않는다. 기계마다 한 번:

```sh
brew uninstall --cask aerospace     # 깔려 있으면
brew uninstall --cask iterm2 postman
brew uninstall rift                 # upstream rift formula 가 남아 있으면
rm -rf ~/.config/aerospace
```
