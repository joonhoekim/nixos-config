# 2026-08-13 — mn56: Windows 전용 BIOS 업데이트를 리눅스에서 해냈다

환경: NixOS 26.11, systemd-boot, Firebat MN56 (Ryzen 7 7840HS), AMI Aptio, BIOS 1.00 (2024-01-13 빌드).

고장 기록이 아니라 수술 기록이다. 이 박스에는 펌웨어가 용의자인 결함이
셋 쌓여 있었고 — s2idle 무한잠수([8/4 문서](2026-08-04-mn56-s2idle-wifi.md)),
warm reboot 의 1/3 이 POST 에 못 닿는 것, 부팅은 되는데 화면만 안 나오는 변종 —
제조사의 마지막 BIOS 는 Windows 플래셔로 배포된다. Windows 는 없다.
결론부터: **패키지 안에 UEFI Shell 플래셔가 같이 들어 있어서, Windows 없이
부트 메뉴 항목 하나로 끝났다.** ROM Writer 를 살 필요도 없었다.

---

## 1. 패키지를 열어 보니 길이 두 개다

`_temp/AR6000-MI2_PHX_250311_Firebat_DIS_SEC/` (리포에는 안 올린다 — AMI
플래셔와 펌웨어 이미지는 재배포 라이선스가 없다):

| 파일 | 정체 |
|---|---|
| `AFUWINx64.EXE`, `amifldrv64.sys`, `WinFlash.bat` | Windows 경로. 무시 |
| `AfuEfix64.efi`, `EfiFlash.nsh` | **UEFI Shell 경로. 이걸 쓴다** |
| `AR6000-MI2.rom` | 이미지 본체, 32 MiB |

`EfiFlash.nsh` 는 한 줄이다: `AfuEfix64.efi AR6000-MI2.rom /p /b /n /k /RLC:E /reboot`.
제조사가 셸에서 뭘 실행하는지 이미 다 적어 놨다. "Windows 용"이라는 말은
포장일 뿐이었다.

## 2. 굽기 전에 ROM 이 진짜 이 보드 것인지 읽는다

이름만 믿고 32 MiB 를 SPI 에 붓고 싶지는 않았다. AMI 이미지에는 `$FID`
태그가 있고, 거기 신원이 들어 있다.

```
$ grep -aboE '\$FID' AR6000-MI2.rom          # 오프셋 두 곳 (본체 + 복구 사본)
$ dd if=AR6000-MI2.rom bs=1 skip=27263604 count=120 | xxd
  $FID.x.1AZKH011 ... 05.29.01.00 ... e907 030b   ← 0x07e9=2025, 03, 0x0b=11
```

- 프로젝트 `1AZKH011`, 빌드 **2025-03-11** — 디렉터리명의 `250311` 과 일치.
- 크기 32 MiB — `dmidecode` 가 보고하는 ROM Size 와 일치.
- 보드 `MI2-SC` — `/sys/class/dmi/id/board_name` 과 일치.
- **버전 문자열은 새 ROM 도 "1.00" 이다.** 플래시 후 확인은 버전이 아니라
  `dmidecode -t bios` 의 Release Date 로 해야 한다 (01/13/2024 → 03/11/2025).

## 3. 백업: flashrom 은 안 되고, 플래셔 자신은 된다

리눅스에서 `flashrom -p internal -r` 로 기존 이미지를 뜨려 했는데, 이
플랫폼에서는 SPI 칩(XM25QU512C)이 인식만 되고 매핑이 안 된다:

```
Could not map flash chip XM25QU512C/XM25QU512D at 0x00000000fc000000.
This flash part has status NOT WORKING for operations: PROBE READ ERASE WRITE
```

최신 AMD 는 PSP 가 SPI 를 쥐고 있어서 OS 쪽 읽기가 막혀 있는 게 보통이다.
대신 AFU 플래셔 자신이 `/O` 플래그로 현재 이미지를 파일로 덤프할 수 있다.
**백업은 플래시 직전, 같은 셸에서 뜬다.** 벽돌이 나면 이 백업도 못 쓰지만
(플래셔가 돌 환경이 같이 사라진다), "새 BIOS 가 부팅은 되는데 더 나빠졌다"
시나리오에서는 같은 절차로 되돌리는 용도가 된다.

## 4. NixOS 쪽 준비는 옵션 하나 + 파일 두 개

```nix
boot.loader.systemd-boot.edk2-uefi-shell.enable = true;   # 부트 메뉴에 셸 항목
```

```
$ sudo cp AfuEfix64.efi AR6000-MI2.rom /boot/    # ESP 는 FAT32, 여유 2 GB
$ sudo nixos-rebuild boot --flake .#mn56
```

USB 스틱도, Ventoy 도, FreeDOS 도 필요 없다. ESP 가 곧 플래셔의 작업
디렉터리다.

## 5. 실행

재부팅 → 부트 메뉴에서 "EDK2 UEFI Shell" →

```
FS0:                                     # 파일이 안 보이면 map -r
AfuEfix64.efi mn56-bios-backup.rom /O    # ① 백업 먼저
AfuEfix64.efi AR6000-MI2.rom /p /b /n /k /RLC:E /reboot   # ② 제조사 라인 그대로
```

②가 끝나면 스스로 재부팅한다. 이번엔 둘 다 한 번에 통과했다.

## 6. 플래시 후에 실제로 벌어진 일

걱정했던 것과 실제로 온 것이 달랐다.

- **부트 항목은 살아남았다.** `/n` 이 NVRAM 을 다시 쓰니 "NixOS 항목이
  사라지면 ESP 폴백(`\EFI\BOOT\BOOTX64.EFI`)으로 부팅 → `nixos-rebuild boot`
  로 재등록" 시나리오까지 준비해 뒀는데, Boot0001 (Linux Boot Manager) 이
  그대로 남아 첫 부팅부터 정상 경로로 올라왔다.
- **대신 유령이 생겼다.** `efibootmgr` 에 Windows Boot Manager, proxmox,
  OpenCore, 중복 Linux/Fallback 넷 — 전부 실존하지 않는 VenHw 경로다.
  제조사 기본 NVRAM 의 잔재로 보인다. BootOrder 선두가 정상 항목이라
  무해하고, 거슬리면 `efibootmgr -b XXXX -B` 로 지운다.
- **S3 는 여전히 없다.** 새 BIOS 도 `ACPI: PM: (supports S0 S4 S5)`.
  s2idle 이 유일한 suspend 라는 사실은 변하지 않았으므로, sleep 마스킹은
  s2idle 재시험을 통과하기 전까지 그대로 간다.
- ACPI 테이블 버그 4건(`\_SB.PCI0.GPP6.WLAN` 미해결 심볼 등)은 신구 BIOS
  가 정확히 같은 4건. 회귀도 개선도 아니다.

## 다시 하게 되면

- 현재 버전 확인: `sudo dmidecode -t bios` — **Release Date 를 본다.**
  버전 문자열은 안 바뀐다.
- ROM 신원 확인: `$FID` 오프셋을 `grep -aboE '\$FID'` 로 찾아 `dd | xxd`.
  날짜는 리틀엔디언 연도 2바이트 + 월 + 일.
- 절차 전문은 `hosts/nixos/mn56/default.nix` 의 "BIOS update staging" 주석에
  있다 (검증이 끝나면 블록째 지워질 예정이라, 그때는 이 문서가 원본이 된다).
- 구 BIOS 백업: `_temp/bios-backup-mn56-20260813/mn56-bios-1.00-20240113.rom`
  (sha256 `db4fd85d…`). **`_temp` 는 git 밖이라 이 디스크에만 존재한다** —
  다른 곳에 사본을 하나 둘 것. 되돌리기 = 5번 절차에서 rom 파일만 이것으로.

## 남은 것

- [x] s2idle 재시험 (당일): `rtcwake -m mem` 90초 + 120초, 둘 다
      entry/exit 쌍 정상, RTC 정시 기상, WiFi 생존, 에러 0. 다만 이 박스의
      실패 이력은 짧은 사이클은 통과하고 긴 사이클에서 죽는 패턴이었으므로
      (2분 hibernate 통과 / 13.4h 사망), **마스킹을 풀고 실사용으로 평가하기로
      했다.** resumeDevice 도 같이 복구 (hibernate 가 다시 닿을 수 있으니).
- [ ] 실사용 평가: 밤샘 suspend, suspend-then-hibernate 가 자연히 굴러가는지.
      다시 안 깨어나면 → 마스킹 다섯 개 복원 (git 이력에 있다).
- [ ] warm reboot 재시험: `reboot=pci` 제거 실험. 부팅 무출력 재발 관찰.
- [ ] 끝나면 정리: ESP 의 플래셔/rom/백업 삭제, `edk2-uefi-shell` 옵션 제거,
      `reboot=pci` 주석 갱신.
