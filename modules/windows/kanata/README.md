# kanata — Windows 의 Caps Lock 레이어

[kanata](https://github.com/jtroo/kanata) 로 NixOS(`modules/nixos/keyboard.nix` +
`modules/nixos/pointer/`)·macOS(`modules/darwin/rice/karabiner/`)와 같은 레이어를
Windows 에 건다. 키 배치와 수치는 그쪽이 정본이고 [`kanata.kbd`](kanata.kbd) 는
그것을 옮긴 것이다.

| 입력 | 결과 |
|---|---|
| Caps 탭 / 홀드 | Caps Lock / 레이어 |
| 레이어 + `ijkl` `u/o` `h/n` `p/m` `y` `/` | 화살표, Home/End, PgUp/PgDn, Bksp/Del, Ins, Ctrl+F |
| 레이어 + `wasd` (Shift: 저속) | 포인터 700 px/s (100 px/s) |
| 레이어 + `q/e` (Shift: 가로) | 휠 |
| 레이어 + `f`·`8` / `r`·`0` / `9` | 왼쪽 / 오른쪽 / 가운데 버튼 (누르는 동안) |
| 오른쪽 Alt | 한/영 — kanata 가 아니라 Windows 자판 배열이 한다 |

## 설치

winget 에는 GUI 래퍼(`jtroo.kanata_gui`)만 있고 본체가 없어서 릴리스에서 받는다.

```powershell
$d = "$env:LOCALAPPDATA\Programs\kanata"
New-Item -ItemType Directory -Force $d | Out-Null
gh release download v1.12.0 --repo jtroo/kanata -D $d -p windows-binaries-x64.zip -p sha256sums --clobber
(Get-FileHash "$d\windows-binaries-x64.zip").Hash   # sha256sums 의 값과 비교
Expand-Archive -Force "$d\windows-binaries-x64.zip" $d
```

zip 안의 실행 파일 중 쓰는 것은 둘이다.

- `kanata_windows_tty_winIOv2_x64.exe` — 콘솔에 로그가 찍힌다. 설정을 고칠 때.
- `kanata_windows_gui_winIOv2_x64.exe` — 콘솔 없이 트레이 아이콘으로 뜬다. 상시 실행용.

`wintercept` 변형은 Interception 드라이버가 있어야 하고, `cmd_allowed` 변형은
설정에서 셸 명령을 실행할 수 있게 한다. 둘 다 필요 없다.

## 시험 실행

레포 루트에서:

```powershell
& "$env:LOCALAPPDATA\Programs\kanata\kanata_windows_tty_winIOv2_x64.exe" --cfg modules\windows\kanata\kanata.kbd
--check   # 위 명령 끝에 붙이면 설정 검증만 하고 끝난다
```

키가 꼬이면 **왼쪽 Ctrl + Space + Esc** 를 함께 누른다. 리매핑 전의 입력을 보는
kanata 내장 탈출구라 설정과 무관하게 종료된다.

## 로그인 시 자동 실행

작업 스케줄러에 로그온 트리거로 등록한다. 관리자 PowerShell 에서 레포 루트로 와서:

```powershell
$exe = "$env:LOCALAPPDATA\Programs\kanata\kanata_windows_gui_winIOv2_x64.exe"
$cfg = (Resolve-Path modules\windows\kanata\kanata.kbd).Path
$action   = New-ScheduledTaskAction -Execute $exe -Argument "--cfg `"$cfg`""
$trigger  = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0 `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask kanata -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
Start-ScheduledTask kanata
```

시작 프로그램 폴더의 바로 가기 대신 작업 스케줄러를 쓰는 이유와, 각 설정이 없으면
생기는 일:

- `-RunLevel Highest` — 관리자 권한으로 띄운다. 보통 권한의 키보드 훅은 작업
  관리자 같은 관리자 권한 창이 앞에 있을 때 입력을 받지 못한다(UIPI). 그 창
  위에서만 레이어가 조용히 안 먹는다. 바로 가기로는 로그인 때 권한 상승을 할 수
  없다.
- `-ExecutionTimeLimit 0` — 기본값은 72시간이고, 넘기면 스케줄러가 kanata 를
  끝낸다. 사흘쯤 켜 둔 뒤 레이어가 갑자기 사라진다.
- `-AllowStartIfOnBatteries` `-DontStopIfGoingOnBatteries` — 기본값은 배터리일 때
  시작하지 않고, 전원을 뽑으면 멈춘다. 노트북에서 전원 상태에 따라 레이어가 있다
  없다 한다.

설정 파일은 레포의 것을 직접 가리킨다. 고친 뒤에는 트레이 메뉴의 reload 나
`Stop-ScheduledTask kanata; Start-ScheduledTask kanata` 로 다시 읽힌다.

해제:

```powershell
Unregister-ScheduledTask kanata -Confirm:$false
```
