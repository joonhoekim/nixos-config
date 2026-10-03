# Defender 실시간 보호를 끈다 (-Enable 이면 되돌린다). 관리자 권한으로 실행한다.
#
#   powershell -ExecutionPolicy Bypass -File hosts\windows\defender-realtime.ps1
#   powershell -ExecutionPolicy Bypass -File hosts\windows\defender-realtime.ps1 -Enable
#
# Set-MpPreference -DisableRealtimeMonitoring 만으로는 유지되지 않는다. 다른 백신이
# 없으면 Defender 가 얼마 뒤나 재부팅 때 실시간 보호를 다시 켠다. 그래서 그룹
# 정책("Real-time Protection" 아래 설정)과 같은 정책 레지스트리 값을 쓰고,
# Set-MpPreference 는 지금 바로 적용하는 데에만 쓴다.
#
# 변조 방지(Tamper Protection)가 켜져 있으면 정책 값은 써지지만 Defender 가 무시한다.
# 에러 없이 실시간 보호가 그대로 켜져 있는 것으로만 보인다. 변조 방지는 스크립트로
# 끌 수 없어서(그것을 막는 것이 그 기능이다) Windows 보안 > 바이러스 및 위협 방지 >
# 설정 관리에서 손으로 끈다.
#
# Defender 서비스와 파일은 그대로 둔다. Sophia Script 는 시작할 때 WinDefend 등의
# 서비스와 Get-MpPreference 가 살아 있는지 확인하고, 없으면 실행을 거부한다.
param([switch]$Enable)

$ErrorActionPreference = 'Stop'

if ((Get-MpComputerStatus).IsTamperProtected) {
    Write-Error '변조 방지가 켜져 있다. Windows 보안에서 먼저 끈다.'
}

$key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'
$values = 'DisableRealtimeMonitoring', 'DisableBehaviorMonitoring',
          'DisableOnAccessProtection', 'DisableIOAVProtection'

if ($Enable) {
    if (Test-Path $key) { $values | ForEach-Object { Remove-ItemProperty $key $_ -ErrorAction SilentlyContinue } }
    Set-MpPreference -DisableRealtimeMonitoring $false -DisableBehaviorMonitoring $false -DisableIOAVProtection $false
} else {
    New-Item $key -Force | Out-Null
    $values | ForEach-Object { New-ItemProperty $key $_ -Value 1 -PropertyType DWord -Force | Out-Null }
    Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true -DisableIOAVProtection $true
}

# 상태 반영은 몇 초 늦다. 바로 읽으면 끈 직후에도 전부 True 로 나온다.
Start-Sleep -Seconds 5
Get-MpComputerStatus |
    Select-Object RealTimeProtectionEnabled, BehaviorMonitorEnabled, OnAccessProtectionEnabled, IoavProtectionEnabled |
    Format-List
