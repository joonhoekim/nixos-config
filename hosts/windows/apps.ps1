# 기본 설치 앱 정리. 관리자 권한으로 실행한다. ./sophia/apply.ps1 이 -Disable 로 부른다.
#
#   powershell -ExecutionPolicy Bypass -File hosts\windows\apps.ps1 -Disable
#   powershell -ExecutionPolicy Bypass -File hosts\windows\apps.ps1 -Restore
#   powershell -ExecutionPolicy Bypass -File hosts\windows\apps.ps1 -Remove
#
# -Disable  현재 계정에서만 등록을 해제한다. 프로비전 패키지(새 계정에 깔리는 원본)가
#           C:\Program Files\WindowsApps 에 남아서 -Restore 가 다운로드 없이 되돌린다.
#           새로 만드는 계정에는 그대로 깔린다.
# -Restore  -Disable 을 되돌린다. 남아 있는 원본의 AppxManifest.xml 을 다시 등록한다.
#           원본이 없는 앱(프로비전되지 않고 이 계정에만 깔려 있던 것)은 등록 해제와
#           함께 Windows 가 파일까지 지우므로 되돌릴 수 없다 — 스토어에서 다시 받는다.
# -Remove   모든 계정과 프로비전 패키지에서 지운다. 원본이 사라져 -Restore 로는
#           돌아오지 않고, 새 계정이나 기능 업데이트에도 다시 깔리지 않는다.
param(
	[Parameter(Mandatory, ParameterSetName = 'Disable')][switch]$Disable,
	[Parameter(Mandatory, ParameterSetName = 'Restore')][switch]$Restore,
	[Parameter(Mandatory, ParameterSetName = 'Remove')][switch]$Remove
)

#Requires -RunAsAdministrator

# 주석으로 둔 것은 쓸 만한 기본 도구라 남긴다.
$Apps = @(
	"Clipchamp.Clipchamp"
	"Microsoft.BingNews"
	"Microsoft.BingSearch"
	"Microsoft.BingWeather"
	"Microsoft.GamingApp"
	"Microsoft.GetHelp"
	"Microsoft.MicrosoftOfficeHub"
	"Microsoft.MicrosoftSolitaireCollection"
	"Microsoft.OutlookForWindows"
	"Microsoft.PowerAutomateDesktop"
	"Microsoft.Todos"
	"Microsoft.Windows.DevHome"
	"Microsoft.WindowsAlarms"
	"Microsoft.WindowsFeedbackHub"
	"Microsoft.WindowsSoundRecorder"
	"Microsoft.Xbox.TCUI"
	"Microsoft.XboxGamingOverlay"
	"Microsoft.XboxSpeechToTextOverlay"
	"Microsoft.YourPhone"
	"Microsoft.ZuneMusic"
	"MicrosoftCorporationII.QuickAssist"
	"MicrosoftWindows.Client.WebExperience"  # 위젯 보드
	"MicrosoftWindows.CrossDevice"
	"MSTeams"
	# "Microsoft.XboxIdentityProvider"  # 스토어 게임의 Xbox 로그인에 쓰인다
	# "Microsoft.StartExperiencesApp"   # 시작 메뉴 구성 요소
	# "Microsoft.MicrosoftStickyNotes"
	# "Microsoft.WindowsCamera"
	# "Microsoft.Windows.Photos"
	# "Microsoft.Paint"
	# "Microsoft.ScreenSketch"          # 캡처 도구
	# "Microsoft.WindowsCalculator"
	# "Microsoft.WindowsNotepad"
)

switch ($PSCmdlet.ParameterSetName)
{
	'Disable'
	{
		foreach ($app in $Apps)
		{
			# -AllUsers 없이: 이 계정의 등록만 지우고 원본은 남긴다
			Get-AppxPackage -Name $app | Remove-AppxPackage -ErrorAction Continue
		}
	}
	'Restore'
	{
		$Provisioned = Get-AppxProvisionedPackage -Online
		foreach ($app in $Apps)
		{
			if (Get-AppxPackage -Name $app) { continue }  # 이미 등록돼 있다
			# 원본 위치: 다른 계정에 남은 설치본, 없으면 프로비전 패키지
			$manifest = Get-AppxPackage -Name $app -AllUsers |
				Where-Object -FilterScript {$_.InstallLocation} |
				ForEach-Object -Process {Join-Path $_.InstallLocation AppxManifest.xml} |
				Where-Object -FilterScript {Test-Path $_} |
				Select-Object -First 1
			if (-not $manifest)
			{
				$manifest = $Provisioned | Where-Object -FilterScript {$_.DisplayName -eq $app} |
					ForEach-Object -Process {$_.InstallLocation -replace '^%SYSTEMDRIVE%', $env:SystemDrive} |
					Where-Object -FilterScript {Test-Path $_} |
					Select-Object -First 1
			}
			if ($manifest)
			{
				Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction Continue
			}
			else
			{
				Write-Warning "$app 의 원본이 없다. 스토어에서 다시 받는다."
			}
		}
	}
	'Remove'
	{
		$Provisioned = Get-AppxProvisionedPackage -Online
		foreach ($app in $Apps)
		{
			Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue
			$Provisioned | Where-Object -FilterScript {$_.DisplayName -eq $app} |
				Remove-AppxProvisionedPackage -Online -ErrorAction Continue | Out-Null
		}
	}
}
