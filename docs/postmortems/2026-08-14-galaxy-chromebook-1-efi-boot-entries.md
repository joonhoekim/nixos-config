# 2026-08-14 — galaxy-chromebook-1: `bootctl status` 가 안 보여 준 죽은 부트 항목 둘

환경: NixOS 26.11, systemd-boot, Samsung Galaxy Chromebook 1, EDK II (UEFI 2.70),
systemd 261.1, 커널 7.1.8.

원인 규명에 실패한 기록이다. 증상은 사라졌고 재발도 없지만, **누가 device path 를
0 으로 만들었는지는 끝내 못 잡았다.** 대신 가는 길에 반증한 가설 셋이 다음에 훨씬
비싼 시간을 아껴 줄 것이라 남긴다.

---

## 증상

부팅이 정상 경로로 안 올라오고 폴백으로만 되는 것처럼 보였다. 시기가 8/13 mn56
BIOS 플래싱([8/13 문서](2026-08-13-mn56-bios-update.md)) 직후라 그쪽 작업이 샌
줄 알았는데, 그 커밋들은 `hosts/nixos/mn56/` 와 `docs/` 만 건드린다. 호스트가
다르고 NVRAM 은 기계마다 따로다 — 시기만 겹쳤다.

## 진짜 함정: `bootctl status` 는 이 문제를 못 보여 준다

처음 뜬 `bootctl status` 는 이렇게 말했다.

```
Boot Loaders Listed in EFI Variables:
        Title: Linux Boot Manager
           ID: 0x0006      ← 정상
        Title: Linux Boot Manager
           ID: 0x0004      ← 사라진 파티션(ad4057b6)을 가리킴
```

죽은 항목 하나로 보인다. 그런데 `efibootmgr -v` 는 **다른 그림**을 보여 줬다.

```
BootOrder: 0003,0004,0006,0001,0000,0002
                      ↑ 실제로 부팅되는 유일한 항목이 세 번째

Boot0003* Linux Boot Manager           HD(0,GPT,00000000-0000-0000-0000-000000000000,0x0,0x0)/\EFI\systemd\systemd-bootx64.efi
Boot0004* Fallback Linux Boot Manager  HD(0,GPT,00000000-0000-0000-0000-000000000000,0x0,0x0)/\EFI\systemd\systemd-boot-fallbackx64.efi
Boot0006* Linux Boot Manager           HD(1,GPT,55de90aa-…,0x1000,0x200000)/\EFI\systemd\systemd-bootx64.efi
```

파티션 번호 0, GUID 전부 0, 시작·크기 0. 가리키는 장치가 없다. 펌웨어는 BootOrder
선두의 이 둘을 차례로 시도해 실패하고 나서야 `0006` 에 닿는다.

**`bootctl status` 는 device path 를 해석할 수 있는 항목만 나열한다.** 해석이 안
되는 항목 — 즉 정확히 우리가 찾던 것 — 은 목록에서 조용히 빠진다. 부트 항목을
의심할 때 `bootctl status` 만 보면 안 된다. `efibootmgr -v` 를 봐야 한다.

## 반증한 가설 셋

시기상 유력한 용의자가 있었다. 8/10 nixpkgs pin(`38cd440`)이 systemd 를
260.1 → 261 로 올렸고, 261 NEWS 에 이런 항목이 있다.

> bootctl now stores the existing systemd-boot binary as a fallback when
> installing a new version, and **installs a fallback UEFI boot entry**, to
> allow a system to recover from a non-working version being installed.

`Boot0004` 의 제목이 말 그대로 `Fallback Linux Boot Manager` 이고, ESP 의
`systemd-boot-fallbackx64.efi` 는 8/14 05:09(= pin 올린 뒤 첫 리빌드)에 처음
생겼다. 260.1 바이너리에는 `systemd-boot-fallback` 문자열 자체가 없다
(`strings` 로 확인). 정황은 완벽했다. 그리고 셋 다 틀렸다.

| 가설 | 검증 방법 | 결과 |
|---|---|---|
| systemd 261 의 bootctl 이 device path 를 0 으로 쓴다 | `bootctl install` 직접 실행 후 즉시 `efibootmgr -v` | **반증.** `HD(1,GPT,55de90aa-…)` 정상 기록. 게다가 기존 항목을 중복 생성하지 않고 `Updated` |
| 리빌드마다 되살아난다 | ESP 로더를 260.1 로 되돌려 stale 상태를 만든 뒤 `nixos-rebuild boot` | **반증.** 파일은 갈아엎었는데 부트 항목은 하나도 안 만듦 |
| 펌웨어가 부팅 때 만들어 낸다/되살린다 | NVRAM 을 깨끗이 비우고 재부팅 2회 | **반증.** 아무것도 안 생김 |

두 번째 검증에서 알게 된 것이 따로 중요하다. **NixOS 의 systemd-boot 빌더는
평소에 EFI 변수를 건드리지 않는다.**

- 평소 경로는 Varlink `io.systemd.BootControl.Install` (`operation=update`) —
  ESP 파일만 갱신하고 NVRAM 은 그대로 둔다.
- CLI `bootctl install` 은 `NIXOS_INSTALL_BOOTLOADER=1` 일 때만 탄다
  (= `nixos-rebuild --install-bootloader`, `nixos-install`). `apps/build-switch`
  는 이 플래그를 안 준다.

즉 `Fallback Linux Boot Manager` 항목이 NVRAM 에 들어오는 경로는 사실상
`--install-bootloader` 뿐이다. 일상 리빌드로는 안 생긴다.

## 고침

죽은 항목 둘을 지운 것이 전부다.

```bash
sudo efibootmgr -b 0003 -B
sudo efibootmgr -b 0004 -B
```

`BootOrder` 는 `0006,0001,0000,0002` 가 되고, 재부팅 2회 뒤에도 그대로다.
`canTouchEfiVariables = false` 같은 설정 변경은 필요 없었다 — 애초에 리빌드가
NVRAM 을 안 건드리므로 막을 것이 없다.

## 다음에 빨리 잡는 법

1. **`efibootmgr -v` 부터 본다.** `bootctl status` 는 깨진 항목을 숨긴다.
2. device path 에서 볼 것은 두 가지다.
   - `HD(0,GPT,00000000-…,0x0,0x0)` → 파티션 정보를 잃은 항목. 부팅 불가.
   - 실재하지 않는 partuuid → 사라진 파티션의 잔재.
     `ls -l /dev/disk/by-partuuid | grep <uuid>` 로 확인.
3. `BootOrder` 선두가 유효한 항목인지 본다. 죽은 항목이 앞에 있으면 부팅은 되지만
   `Booting from 'Linux Boot Manager' failed: Not Found` 를 거쳐서 온다.
4. 지우는 건 `efibootmgr -b XXXX -B`. `bootctl` 로는 못 지운다.
5. 최악의 경우에도 `\EFI\BOOT\BOOTX64.EFI`(removable 폴백)와 펌웨어가 자동 생성한
   `NVMe: …` 항목이 남아 있다. NVRAM 을 통째로 날려도 부팅 경로는 있다.

`efibootmgr` 를 `nix run` 이 아니라 `environment.systemPackages` 로 상비하는
이유가 이것이다 — 진단해야 할 상황이 곧 "부팅이 이상한" 상황이라, 그때 패키지를
받으러 갈 수는 없다.

## 남은 것

- [ ] **원인 미확정.** `Boot0003`/`Boot0004` 의 device path 를 0 으로 만든 주체를
      못 잡았다. bootctl 도, 리빌드도, 재부팅도 아니다. 재현이 안 되는 이상 더
      파는 건 비싸다. **다시 나타나면 그때가 진짜 단서** — 그 시점에
      `sudo efibootmgr -v` 를 먼저 뜨고, 직전에 무엇을 했는지(특히
      `--install-bootloader` 를 준 리빌드, warm reboot, 전원 차단)를 같이 적을 것.
- [x] 옛 `Boot0004`(사라진 파티션 `ad4057b6`)도 같이 정리됐다.
      `hosts/nixos/galaxy-chromebook-1/default.nix` 의 주석이 서술하던 상황이다.
