# 디스크 공간 — 어디에 쌓이고, 무엇을 지워도 되나

디스크가 차는 자리와 지우는 법을 적는다. 앞의 두 절은 macOS·NixOS 공통이고, 그
아래가 OS 별이다.

macOS 에서 앱 캐시처럼 **경로가 고정된** 대상은 [`apps/reclaim`](../apps/reclaim) 이
재서 보여주고 지운다. 이 문서는 그 바깥을 다룬다 — 프로젝트마다 경로가 달라서
스크립트에 목록으로 넣을 수 없는 개발 산출물, 그리고 지울 때 판단이 필요한
VM·컨테이너 데이터.

수치는 macOS 27.0.1 (26A434), colima 0.10.3, docker CLI 29.8.0, turbo 2.10 에서 잰
것이다(2026-10-16).

---

## 상한 없이 자라는 것

아래 셋은 **자동 정리가 없다.** 쓰는 동안 계속 커지고, 지우기 전까지 줄지 않는다.
한 번 잴 때 세 자리가 합쳐서 100G 를 넘었다(turbo 35G, cargo 17G, docker 빌드 캐시
29.5G + 안 쓰는 이미지).

```sh
du -sh ~/git/*/.turbo ~/git/*/*/target ~/git/*/target 2>/dev/null   # 어느 프로젝트에 쌓였나
```

### turbo 로컬 캐시 — `<repo>/.turbo/cache`

태스크 입력 해시마다 출력이 `<hash>.tar.zst` 로 하나씩 생긴다. 소스를 고칠 때마다
해시가 바뀌므로 파일이 계속 늘고, turbo 는 오래된 것을 지우지 않는다. 약 두 달에
30,633 개, 35G 였다.

```sh
rm -rf <repo>/.turbo/cache     # 다음 빌드가 캐시 미스로 한 번 느려질 뿐이다
```

`.turbo/daemon` 은 데몬 상태라 남겨도 된다(수십 KB).

### cargo — `<crate>/target`

의존성 버전·feature·rustc 버전이 바뀌면 새 산출물이 생기고, 이전 것은 남는다.
`debug/incremental` 도 크다. debug 14G + release 2.6G 였다.

```sh
cargo clean                    # target/ 전체. 다음 빌드는 처음부터
cargo sweep --time 30          # cargo-sweep 이 있으면 30일 안 쓴 산출물만
```

### docker — 이미지와 빌드 캐시

`docker build` 를 할 때마다 빌드 캐시가 쌓이고, 태그가 갱신된 이전 이미지는 dangling
으로 남는다. macOS 에서는 데몬이 colima VM 안에 있으니 먼저 `colima start` 한다.

```sh
docker system df                           # 무엇이 얼마나 회수 가능한가
docker image prune -a -f                   # 어떤 컨테이너도 참조하지 않는 이미지
docker builder prune -a -f                 # 빌드 캐시 전부
```

**`docker system prune -a --volumes` 를 기본으로 쓰지 않는다.** 이 명령은 먼저
정지된 컨테이너를 지우고, 그 다음 그 컨테이너들이 쓰던 이미지와 볼륨까지 "안 쓰는
것" 으로 본다. compose 로 띄우는 개발 스택은 평소에 정지 상태라 postgres 볼륨 같은
데이터가 같이 사라진다. `image prune -a` 는 정지된 컨테이너가 참조하는 이미지를 남긴다.

볼륨은 `docker system df -v` 로 하나씩 보고, 이름을 보고 버려도 되는 것만
`docker volume rm <name>` 한다. `LINKS 0` 이라고 해서 버려도 되는 것은 아니다 —
CI 캐시처럼 일부러 이름을 붙여 둔 볼륨이 그렇게 보인다.

## 패키지 매니저 캐시

다시 받으면 되는 것들이다. 각각 수 GB 까지 자란다. 명령은 같고 경로만 OS 마다 다르다.

| 도구 | 정리 | macOS | Linux |
|---|---|---|---|
| uv | `uv cache clean` | `~/.cache/uv` | `~/.cache/uv` |
| npm | `npm cache clean --force` | `~/.npm` | `~/.npm` |
| pnpm store | `pnpm store prune` | `~/Library/pnpm/store` | `~/.local/share/pnpm/store` |
| pnpm 메타데이터 | 디렉터리째 삭제 | `~/Library/Caches/pnpm` | `~/.cache/pnpm` |
| bun | `bun pm cache rm` | `~/.bun/install/cache` | `~/.bun/install/cache` |

pnpm store 는 캐시 디렉터리 밖(`pnpm store path`)에 있어서 캐시 디렉터리만 재면
놓친다. 프로젝트의 `node_modules` 가 store 를 하드링크하므로, `du` 로 잰 store 크기만큼
다 줄지는 않는다 — 아직 쓰는 패키지는 링크가 남아 지워지지 않는다.

nix 세대는 양쪽 다 `nix run .#clean` 이다. 주간 자동 GC(30일)가
`hosts/darwin/common.nix` · `hosts/nixos/common.nix` 의 `nix.gc` 에 있다.

---

## macOS

### 먼저 잰다

```sh
df -h /                                   # 전체 여유
tmutil listlocalsnapshots /               # Time Machine 로컬 스냅샷. 업데이트 직후에 남기도 한다
diskutil apfs list | grep -E 'Role|Consumed'   # 볼륨별 사용량
du -sh ~/.[!.]* ~/* ~/Library/* 2>/dev/null | sort -h | tail -20
nix run .#reclaim -- --list               # 앱 캐시. 재기만 하고 지우지 않는다
```

`diskutil apfs list` 에서 역할이 없는(`No specific role`) 볼륨이 Nix Store 다. `/nix`
는 Data 볼륨 밖에 있어서 `du ~` 에는 잡히지 않는다. 설정 > 저장 공간은 이 볼륨을
"System Data" 로 집계한다 — 범용 클리너를 쓰면 안 되는 이유는 `apps/reclaim` 머리말에
있다.

Preboot 볼륨은 OS 업데이트 직후 10G 넘게 커질 수 있다. macOS 가 재부팅 몇 번 안에
스스로 줄이니 손대지 않는다.

### colima — `~/.colima/_lima/_disks`

colima 의 Docker 데이터 디스크(`/mnt/lima-colima`)는 호스트에서 sparse 파일이다.
VM 안에서 지운 블록이 호스트 파일 크기에도 반영되어, 위의 docker prune 만으로 54G →
6.7G 가 되었다(`fstrim` 을 따로 돌려도 더 줄지 않았다). 그러니 디스크가 크게 보여도
`colima delete` 까지 갈 필요는 보통 없다.

`colima delete` 는 VM 과 그 안의 이미지·컨테이너·볼륨 전부를 지운다. 다시
`colima-up`(`modules/darwin/scripts/colima-up.sh`)하면 빈 VM 이 생긴다.

### lima — `~/.lima/<name>`

colima 와 별개로 `limactl` 로 만든 VM 이다. `limactl list` 로 보고, 안 쓰는 것은
`limactl delete <name>`. 디스크 이미지 다운로드 캐시는 `~/Library/Caches/lima` 에 따로
쌓인다(VM 을 다시 만들 때 쓰인다).

### Xcode iOS DeviceSupport

`~/Library/Developer/Xcode/iOS DeviceSupport` 는 실기기를 연결할 때 iOS 버전별로
심볼을 받아 두는 자리다. 버전마다 수 GB 다. 지워도 다음 연결 때 다시 받는다.

---

## NixOS

`apps/reclaim` 은 macOS 전용이다. NixOS 에서는 앱 캐시가 대부분 `~/.cache` 한 곳에
모여서 따로 목록을 들 필요가 적다.

### 먼저 잰다

```sh
df -h / /home /nix
du -sh ~/.[!.]* ~/* ~/.cache/* 2>/dev/null | sort -h | tail -20
du -sh /nix/store                       # 오래 걸린다. 세대 수는 nix-env --list-generations -p /nix/var/nix/profiles/system
sudo du -sh /var/lib/docker /var/log/journal
```

### docker — `/var/lib/docker`

VM 없이 호스트에서 돈다(`hosts/nixos/common.nix` 의 `virtualisation.docker`). 위의
prune 명령이 그대로 통하고, 지운 만큼 바로 줄어든다. 컨테이너 로그는 같은 자리에서
`max-size`/`max-file` 로 컨테이너당 30MB 로 묶여 있다.

### journald — `/var/log/journal`

```sh
journalctl --disk-usage
sudo journalctl --vacuum-size=500M      # 오래된 것부터 지워 이 크기에 맞춘다
```

journald 는 기본으로 파일시스템의 10% (최대 4G) 까지 쓴다.
