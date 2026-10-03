<#
	Sophia Script 7.3.0 프리셋 — Windows 11 정리. 직접 실행하지 않는다.
	./apply.ps1 이 Sophia 배포본의 Sophia.ps1 자리에 이 파일을 복사해서 실행한다.
	$PSScriptRoot\Module 을 읽으므로 배포본 폴더 안에 있어야만 돈다.

	범위: 텔레메트리, 광고·추천, Copilot·Recall, 위젯, OneDrive, 기본 앱, 백그라운드
	서비스는 끈다. Edge 는 지우지 않고 끼어드는 동작만 막는다. 취향 설정(다크 모드,
	작업 표시줄 정렬, 커서 등)은 넣지 않는다.

	모든 Sophia 함수는 반대쪽 스위치(-Enable/-Show 등)로 되돌릴 수 있다. 아래 "Sophia
	밖" 절은 되돌리는 법을 그 자리에 적는다.

	Sophia 기본 프리셋에서 일부러 뺀 것:
	- RecommendedTroubleshooting -Automatically: 진단 데이터 수준을 "선택 사항"으로
	  올리고 오류 보고를 다시 켠다. 위 텔레메트리 설정을 조용히 되돌린다.
	- Microsoft Defender 절 전부: 실시간 보호는 ../defender-realtime.ps1 이 끈다.
	  NetworkProtection·DefenderSandbox 등을 켜면 끈 것과 반대로 부하가 는다.
	- Uninstall-UWPApps, WindowsFeatures, WindowsCapabilities: 대화 상자로 고르는
	  방식이라 파일로 남지 않는다. 기본 앱은 ../apps.ps1 이 목록으로 다룬다.
	- GPUScheduling, Hibernation: 이 기기(EVO-T1)는 내장 GPU 라 Sophia 가 건너뛰고,
	  최대 절전은 이미 꺼져 있다(hiberfil.sys 없음).
#>

#Requires -RunAsAdministrator
#Requires -Version 5.1

#region Initial Actions
$Global:Failed = $false

Get-ChildItem function: | Where-Object {$_.ScriptBlock.File -match "Sophia_Script_for_Windows"} | Remove-Item -Force
Remove-Module -Name SophiaScript -Force -ErrorAction Ignore
Import-Module -Name $PSScriptRoot\Module\Manifest\SophiaScript.psd1 -PassThru -Force
Get-ChildItem -Path $PSScriptRoot\Module\private | Foreach-Object -Process {. $_.FullName}

# -Warning 은 "프리셋을 고쳤는지 확인하라"는 대화식 경고다. 이 파일이 고친 프리셋이다.
InitialActions

if ($Global:Failed)
{
	exit
}
#endregion Initial Actions

#region Protection
# 로그는 배포본 폴더에 남는다
Logging
#endregion Protection

#region 텔레메트리
DiagTrackService -Disable
DiagnosticDataLevel -Minimal
ErrorReporting -Disable
FeedbackFrequency -Never
# ScheduledTasks -Disable 은 체크 상자 대화 상자를 띄우고 답할 때까지 멈춘다.
# 같은 작업 목록을 아래 "Sophia 밖" 절에서 직접 끈다.
SigninInfo -Disable
LanguageListAccess -Disable
AdvertisingID -Disable
TailoredExperiences -Disable
#endregion 텔레메트리

#region 광고·추천
WindowsWelcomeExperience -Hide
WindowsTips -Disable
SettingsSuggestedContent -Hide
AppsSilentInstalling -Disable
WhatsNewInWindows -Disable
BingSearch -Disable
SearchHighlights -Hide
OneDriveFileExplorerAd -Hide
StartRecommendedSection -Hide
StartRecommendationsTips -Hide
StartAccountNotifications -Hide
UseStoreOpenWith -Hide
#endregion 광고·추천

#region Copilot·Recall·위젯·OneDrive
# Recall 기능을 끄고 Copilot 앱을 지운다
WindowsAI -Disable
# TaskbarWidgets -Hide 는 넣지 않는다. 쓰려는 TaskbarDa 값을 UCPD 드라이버가 막아서
# 매번 실패한다. 위젯은 ../apps.ps1 이 위젯 보드 앱의 등록을 해제해서 끈다.
OneDrive -Uninstall
#endregion Copilot·Recall·위젯·OneDrive

#region Edge — 지우지 않고 끼어들기만 막는다
PreventEdgeShortcutCreation -Channels Stable, Beta, Dev, Canary
UnpinTaskbarShortcuts -Shortcuts Edge, Outlook
#endregion Edge

#region 게임
XboxGameBar -Disable
XboxGameTips -Disable
#endregion 게임

#region 성능
# 고성능 전원 관리. 배터리가 없는 데스크톱이라 넣는다. 유휴 전력과 발열이 조금 는다
PowerPlan -High
NetworkAdaptersSavePower -Disable
DeliveryOptimization -Disable
# 업데이트용으로 잡아 둔 약 7GB 를 돌려받는다. 다음 업데이트 설치 뒤에 적용된다
ReservedStorage -Disable
#endregion 성능

#region Sophia 밖
# Sophia 에 해당 함수가 없거나, Sophia 함수가 대화 상자를 띄우는 것들.

function Set-Dword ([string]$Path, [string]$Name, [int]$Value)
{
	if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
	New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
}

# 잠금 화면·시작 메뉴·시스템 제안. Sophia 가 다루지 않는 ContentDeliveryManager 값.
# 되돌리기: 각 값을 1 로.
$cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
Set-Dword $cdm RotatingLockScreenOverlayEnabled 0
Set-Dword $cdm SubscribedContent-338387Enabled 0  # 잠금 화면 팁·광고
Set-Dword $cdm SubscribedContent-338388Enabled 0  # 시작 메뉴 제안
Set-Dword $cdm SystemPaneSuggestionsEnabled 0
Set-Dword $cdm SoftLandingEnabled 0

# 위젯은 정책(HKLM\SOFTWARE\Policies\Microsoft\Dsh AllowNewsAndInterests)으로 끄지
# 않는다. UCPD 드라이버가 이 키를 막아 관리자 권한으로도 "unauthorized operation" 이
# 난다. 위젯은 ../apps.ps1 이 위젯 보드 앱(MicrosoftWindows.Client.WebExperience)의
# 등록을 해제해서 끈다.

# 진단 추적 예약 작업. Sophia ScheduledTasks 의 기본 체크 목록(Sophia.psm1
# $CheckedScheduledTasks)과 같다. 되돌리기: Enable-ScheduledTask.
$DiagTasks = @(
	"MareBackup"
	"Microsoft Compatibility Appraiser"
	"Microsoft Compatibility Appraiser Exp"
	"StartupAppTask"
	"Proxy"
	"Consolidator"
	"UsbCeip"
	"Microsoft-Windows-DiskDiagnosticDataCollector"
	"MapsToastTask"
	"MapsUpdateTask"
)
Get-ScheduledTask | Where-Object -FilterScript {($_.TaskName -in $DiagTasks) -and ($_.State -ne "Disabled")} |
	Disable-ScheduledTask | Out-Null

# Edge 가 스스로 끼어드는 동작. 브라우저로서의 기능은 건드리지 않는다.
# 되돌리기: HKLM\SOFTWARE\Policies\Microsoft\Edge 의 값을 지운다.
$edge = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
Set-Dword $edge StartupBoostEnabled 0          # 로그인 때 미리 띄워 두기
Set-Dword $edge BackgroundModeEnabled 0        # 창을 닫아도 백그라운드에 남기
Set-Dword $edge DefaultBrowserSettingEnabled 0 # 기본 브라우저로 설정하라는 요청
Set-Dword $edge HideFirstRunExperience 1
Set-Dword $edge AutoImportAtFirstRun 4         # 4 = 다른 브라우저 데이터를 가져오지 않음
Set-Dword $edge ShowRecommendationsEnabled 0
Set-Dword $edge PromotionalTabsEnabled 0

# 스토어 앱의 백그라운드 실행. 2 = 강제로 막음. 되돌리기: 값을 지운다.
# 패키지 데스크톱 앱(Windows Terminal, PowerToys 등)은 이 정책의 대상이 아니다.
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" LetAppsRunInBackground 2

# 서비스. 되돌리기: Set-Service <이름> -StartupType <원래 값>
#   WSearch    Automatic — 검색 색인. 끄면 탐색기 파일 검색이 색인 없이 느리게 돈다.
#              시작 메뉴의 앱 검색은 그대로 된다.
#   SysMain    Automatic — 자주 쓰는 앱 미리 읽기. NVMe + 64GB 에서는 얻는 게 적다.
#   dmwappushservice Manual — 텔레메트리용 WAP 푸시 라우팅.
#   MapsBroker Automatic — 오프라인 지도 관리자.
#   RetailDemo Manual — 매장 전시 모드.
# lfsvc(위치)는 남긴다. 끄면 시간대 자동 설정이 멈춘다.
foreach ($svc in "WSearch", "SysMain", "dmwappushservice", "MapsBroker", "RetailDemo")
{
	Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
	Set-Service -Name $svc -StartupType Disabled -ErrorAction Continue
}

#endregion Sophia 밖

PostActions
