#!/bin/sh
#
# 앱 이름 -> Nerd Font 글리프. plugins/front_app.sh 가 source 한다.
#
# 이름은 macOS 가 부르는 이름 그대로여야 한다. front_app_switched 이벤트의 $INFO
# 가 그 값이고, 확인하려면 바를 띄워 둔 채 앱을 전환하면서
# `sketchybar --query front_app | jq -r .label` 을 보면 된다.
#
# 글리프가 네모로 뜨면 폰트에 그 코드포인트가 없는 것이다. 여기 쓰는 것들은 전부
# Nerd Font(modules/shared/fonts.nix 의 JetBrainsMono)에 있는 nf-md-* 계열이다.

__icon_map() {
	case "$1" in
	# 터미널
	"Ghostty") icon_result="󰊠" ;;
	"WezTerm" | "wezterm-gui") icon_result="󰆍" ;;
	"iTerm2") icon_result="󰆍" ;;

	# 에디터 / 개발
	"Code" | "Visual Studio Code") icon_result="󰨞" ;;
	"Zed") icon_result="󰅩" ;;
	"Xcode") icon_result="󰀵" ;;
	"DBeaver") icon_result="󰆼" ;;
	"Redis Insight") icon_result="󰑙" ;;
	"Bruno" | "Postman") icon_result="󰛮" ;;
	"Docker Desktop") icon_result="󰡨" ;;

	# 브라우저
	"Zen" | "Zen Browser") icon_result="󰈹" ;;
	"Google Chrome") icon_result="󰊯" ;;
	"Brave Browser") icon_result="󰖟" ;;
	"Firefox" | "Firefox Developer Edition") icon_result="󰈹" ;;
	"Safari") icon_result="󰀹" ;;

	# 커뮤니케이션 / 문서
	"Slack") icon_result="󰒱" ;;
	"Discord") icon_result="󰙯" ;;
	"Messages") icon_result="󰍡" ;;
	"Mail") icon_result="󰇮" ;;
	"Notion") icon_result="󰎚" ;;
	"Notes") icon_result="󰠮" ;;
	"ONLYOFFICE") icon_result="󰈙" ;;
	"Claude") icon_result="󰚩" ;;

	# 시스템
	"Finder") icon_result="󰀶" ;;
	"System Settings") icon_result="󰒓" ;;
	"Activity Monitor") icon_result="󰄨" ;;
	"Sol") icon_result="󰍉" ;;
	"IINA") icon_result="󰕧" ;;

	# 모르는 앱. 라벨은 어차피 옆에 뜨므로 일반 창 아이콘이면 충분하다.
	*) icon_result="󰖯" ;;
	esac
}
