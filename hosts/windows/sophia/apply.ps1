# Sophia Script 배포본을 받아 ./preset.ps1 을 적용한다. 관리자 권한의 Windows
# PowerShell 5.1 에서 실행한다 (Sophia 의 PowerShell 7 판은 배포본이 따로다).
#
#   powershell -ExecutionPolicy Bypass -File hosts\windows\sophia\apply.ps1
#
# winget 의 TeamSophia.SophiaScript 는 자체 압축 해제 exe 라 프리셋을 바꿔 끼울 자리가
# 보이지 않는다. 그래서 릴리스 zip 을 버전과 해시로 고정해 받는다.
#
# 버전을 올릴 때: 새 배포본의 Sophia.ps1 과 이 폴더의 preset.ps1 을 비교해 함수
# 이름이 바뀌지 않았는지 보고, 아래 세 값을 고친다.

$ErrorActionPreference = 'Stop'

$Version = '7.3.0'
$Zip     = "Sophia.Script.for.Windows.11.v$Version.zip"
$Sha256  = 'D342149E13053EA87C6119706A1F9D7D56D08C6E55CED113B1C32A30E7873BF2'

$Base = "$env:LOCALAPPDATA\Programs\sophia"
$Root = "$Base\Sophia_Script_for_Windows_11_v$Version"

if (-not (Test-Path "$Root\Module\Sophia.psm1"))
{
	New-Item -ItemType Directory -Force $Base | Out-Null
	$out = "$Base\$Zip"
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	Invoke-WebRequest -UseBasicParsing -OutFile $out `
		"https://github.com/farag2/Sophia-Script-for-Windows/releases/download/$Version/$Zip"
	$got = (Get-FileHash $out -Algorithm SHA256).Hash
	if ($got -ne $Sha256) { throw "해시가 다르다: $got" }
	Expand-Archive -Force $out $Base
}

# 배포본의 Sophia.ps1 을 덮어쓴다. 프리셋이 $PSScriptRoot\Module 을 읽기 때문에
# 배포본 폴더 밖에서는 돌지 않는다.
Copy-Item -Force "$PSScriptRoot\preset.ps1" "$Root\Sophia.ps1"

# 위의 Stop 은 다운로드와 해시 검사용이다. 프리셋은 이 값을 물려받으므로 Continue 로
# 되돌린다 — Stop 이면 레지스트리 쓰기 하나가 막혀도 나머지 설정과 앱 처리가 통째로
# 건너뛰어진다.
$ErrorActionPreference = 'Continue'
& "$Root\Sophia.ps1"

# Sophia 의 시작 점검(InitialActions)이 실패하면 프리셋은 아무것도 하지 않고 끝난다.
# 그때는 앱도 건드리지 않는다.
if ($Global:Failed) { throw "Sophia 시작 점검이 실패했다. 위 경고를 본다." }

# 기본 앱은 지우지 않고 이 계정에서만 등록을 해제한다. 되돌리기와 완전 제거는 apps.ps1 머리말.
& "$PSScriptRoot\..\apps.ps1" -Disable
