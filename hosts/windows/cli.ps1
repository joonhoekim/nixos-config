# Windows CLI 도구를 깐다. 관리자 권한은 필요 없다. 몇 번을 다시 돌려도 된다.
#
#   powershell -ExecutionPolicy Bypass -File hosts\windows\cli.ps1
#
# 순서: winget(./cli.winget) → MSVC 빌드 도구 → ADB 고정 → Scoop → mise(./mise.toml) → uv tool → npm.
# 목록마다 줄 맨 앞의 `#` 를 지우면 켜진다. 빈 목록인 단계는 건너뛴다.

$ErrorActionPreference = 'Continue'

# winget 이 새로 단 PATH 는 이 프로세스에 들어오지 않는다. 설치 직후 그 도구를
# 부르려면 레지스트리에서 다시 읽어야 한다.
function Update-Path
{
	$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
	            [Environment]::GetEnvironmentVariable('Path', 'User')
}

# --- winget -----------------------------------------------------------------
winget configure -f "$PSScriptRoot\cli.winget" --accept-configuration-agreements --disable-interactivity
Update-Path

# --- MSVC 빌드 도구 ---------------------------------------------------------
# rust 의 msvc 툴체인(./mise.toml)과 node-gyp 가 link.exe·cl.exe 를 찾는다. 없으면
# rustc 는 깔려 있어도 "linker `link.exe` not found" 로 모든 빌드가 실패한다.
# 워크로드를 --override 로 넘겨야 해서 ./cli.winget 의 WinGetPackage 로는 못 쓴다.
# 설치 프로그램이 UAC 로 스스로 권한을 올린다. 수 GB 다.
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vcTools = if (Test-Path $vswhere)
{
	& $vswhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
}
if (-not $vcTools)
{
	winget install --exact --id Microsoft.VisualStudio.BuildTools --source winget `
		--accept-package-agreements --accept-source-agreements --disable-interactivity `
		--override '--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
}

# --- ADB 고정 ---------------------------------------------------------------
# scrcpy 는 자기 zip 에 든 adb 를 쓰는데 platform-tools 의 adb 와 버전이 다르다.
# 둘이 번갈아 뜨면 서로의 adb 서버를 죽이고 다시 띄워서 기기 연결이 수시로 끊긴다.
# scrcpy 는 환경 변수 ADB 가 있으면 그 adb 를 쓴다.
#
# scrcpy 의 폴더도 PATH 에 있고 거기에도 adb.exe 가 있어서 `Get-Command adb` 의 첫
# 결과는 PATH 순서에 달려 있다. platform-tools 폴더의 것을 이름으로 고른다.
$adb = Get-Command adb -All -ErrorAction SilentlyContinue |
	Where-Object -FilterScript {$_.Source -match '\\platform-tools\\adb\.exe$'} |
	Select-Object -First 1
if ($adb)
{
	[Environment]::SetEnvironmentVariable('ADB', $adb.Source, 'User')
	$env:ADB = $adb.Source
}

# --- Scoop: winget 에 없는 것 -----------------------------------------------
# "버킷/이름". Scoop 이 없으면 설치한다(get.scoop.sh, 사용자 권한).
$Scoop = @(
	# "main/maestro"          # 모바일 E2E. java 가 필요하다 (./mise.toml)
	# "main/bundletool"       # AAB ↔ APK. java 가 필요하다
	# "main/fx"
	# "main/navi"
	# "main/ouch"
	# "main/pngquant"
	# "main/gifsicle"
	# "main/yamlfmt"
	# "main/htmlq"
	# "main/websocat"
	# "main/ghz"
	# "extras/lazysql"
	# "extras/natscli"
	# "extras/process-compose"
)
if ($Scoop)
{
	if (-not (Get-Command scoop -ErrorAction SilentlyContinue))
	{
		Invoke-RestMethod https://get.scoop.sh | Invoke-Expression
		Update-Path
	}
	$Scoop | ForEach-Object {$_.Split('/')[0]} | Sort-Object -Unique |
		Where-Object -FilterScript {$_ -ne 'main'} | ForEach-Object {scoop bucket add $_}
	scoop install @($Scoop)
}

# --- mise: 언어 런타임 ------------------------------------------------------
if (Get-Command mise -ErrorAction SilentlyContinue)
{
	$dir = "$env:USERPROFILE\.config\mise"
	New-Item -ItemType Directory -Force $dir | Out-Null
	Copy-Item -Force "$PSScriptRoot\mise.toml" "$dir\config.toml"
	mise install

	# mise 는 PATH 를 건드리지 않는다. shims 가 PATH 에 없으면 설치는 성공해도 새
	# 셸에서 node·go·cargo 가 "not recognized" 로 나온다. 프로필의 `mise activate`
	# 대신 shims 를 쓰는 것은 Git Bash·cmd·IDE 처럼 프로필을 안 읽는 쪽에서도 보이게
	# 하려는 것이다.
	$shims = "$env:LOCALAPPDATA\mise\shims"
	$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
	if (($userPath -split ';') -notcontains $shims)
	{
		[Environment]::SetEnvironmentVariable('Path', "$shims;$userPath", 'User')
		Update-Path
	}
}

# --- uv tool: 파이썬 CLI -----------------------------------------------------
# PostgreSQL·Redis 의 winget 패키지 대신 클라이언트만 여기서 받는다 (./cli.winget 의
# "인프라·DB·네트워크" 절).
$UvTools = @(
	# "pgcli"
	# "iredis"
	# "sqlfluff"
	# "yamllint"
	# "ocrmypdf"       # ghostscript·tesseract 가 PATH 에 있어야 돈다
	# "shot-scraper"
)
if ($UvTools -and (Get-Command uv -ErrorAction SilentlyContinue))
{
	$UvTools | ForEach-Object {uv tool install $_}
}

# --- npm: LSP·포매터·브라우저 도구 ------------------------------------------
# mise 가 깐 node 의 전역으로 들어간다. mise.toml 에서 node 를 켜야 돈다.
$Npm = @(
	# "@vtsls/language-server"
	# "vscode-langservers-extracted"
	# "@tailwindcss/language-server"
	# "dockerfile-language-server-nodejs"
	# "yaml-language-server"
	# "@fsouza/prettierd"
	# "eslint_d"
	# "markdownlint-cli2"
	# "playwright"
	# "@playwright/mcp"
)
if ($Npm -and (Get-Command mise -ErrorAction SilentlyContinue))
{
	mise exec node -- npm install --global @Npm
}
