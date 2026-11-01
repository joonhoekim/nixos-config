-- 시드다 — ~/.config/wezterm 이 없을 때만 복사되고, 그 뒤로는 저장하는 순간 반영된다(전체 그림: docs/macos-rice.md).

local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- colors.json 이 없는 것(새 머신)이 정상이다 — 그때는 기본 스킴으로 뜬다. 억지로 색을 넣으면
-- "wal 을 돌렸는데 안 바뀐다"와 구별이 안 된다.
local wal_json = wezterm.home_dir .. "/.cache/wal/colors.json"

-- wezterm 은 자기 설정 파일만 감시한다. 이 줄이 없으면 wal 을 돌려도 열린 창은 옛 색 그대로다.
wezterm.add_to_config_reload_watch_list(wal_json)

local function read_wal()
	local f = io.open(wal_json, "r")
	if not f then
		return nil
	end
	local body = f:read("*a")
	f:close()
	-- wal 이 쓰는 도중이면 반쪽 JSON 을 잡을 수 있다 — 설정 전체가 무효가 되느니 색만 포기한다.
	local ok, data = pcall(wezterm.json_parse, body)
	if not ok or type(data) ~= "table" then
		return nil
	end
	return data
end

local wal = read_wal()
if wal and wal.colors and wal.special then
	local c = wal.colors
	config.colors = {
		foreground = wal.special.foreground,
		background = wal.special.background,
		cursor_bg = wal.special.cursor,
		cursor_border = wal.special.cursor,
		-- 커서 밑 글자는 배경색으로 — 커서색을 그대로 쓰면 안 보인다.
		cursor_fg = wal.special.background,
		selection_bg = c.color8,
		selection_fg = wal.special.foreground,
		ansi = { c.color0, c.color1, c.color2, c.color3, c.color4, c.color5, c.color6, c.color7 },
		brights = { c.color8, c.color9, c.color10, c.color11, c.color12, c.color13, c.color14, c.color15 },
	}
end

-- D2Coding 은 한글 셀이 라틴의 정확히 두 배라 한영을 섞어도 열이 안 밀린다(modules/shared/fonts.nix).
config.font = wezterm.font_with_fallback({
	"JetBrainsMono Nerd Font",
	"D2CodingLigature Nerd Font",
	"Apple Color Emoji",
})
config.font_size = 14.0

-- 타일링 WM 밑이라 타이틀바는 뺀다. RESIZE 는 플로팅일 때 마우스로 크기를 잡을 테두리를 남긴다.
config.window_decorations = "RESIZE"
config.window_padding = { left = 8, right = 8, top = 6, bottom = 6 }
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.adjust_window_size_when_changing_font_size = false

-- 왼쪽 Option 은 rift-grid 의 수정자다 — 터미널이 Alt 로 잡으면 그 바인딩이 먹혀 창 전환이 안 된다.
-- 오른쪽 Option 은 조판 문자용으로 남긴다.
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = true

config.scrollback_lines = 10000
config.audible_bell = "Disabled"

return config
