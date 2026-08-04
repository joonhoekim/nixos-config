-- wezterm 설정.
--
-- 이 레포에서 wezterm 은 보조 터미널이다. 일상용은 ghostty 이고
-- (modules/shared/ghostty.nix, apps/rice-term), 여기 있는 이유는 두 가지다:
-- 설정이 Lua 라 pywal 이 뱉은 JSON 을 파일 하나 더 만들지 않고 그대로 읽을 수
-- 있고, 그 파일을 감시 목록에 넣어 두면 팔레트가 바뀔 때 스스로 다시 뜬다.
--
-- ── 이 파일은 시드다 ─────────────────────────────────────────────────────
-- 레포(modules/darwin/rice/wezterm)에서 ~/.config/wezterm 으로 *없을 때만*
-- 복사된다. 고친 뒤 반영은 저장하는 순간 — wezterm 이 자기 설정을 감시한다.

local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- ── pywal 팔레트 ──────────────────────────────────────────────────────────
-- ~/.cache/wal/colors.json 은 apps/rice-colors 가 `wal` 을 돌릴 때마다 다시
-- 쓰인다. 없을 수도 있다는 게 정상 상태다 — 새 머신은 wal 을 한 번도 안 돌렸다.
-- 그때는 색 지정을 통째로 건너뛰고 wezterm 기본 스킴으로 뜬다. 억지로 색을
-- 만들어 넣으면 "wal 을 돌렸는데 안 바뀐다"와 구별이 안 된다.
local wal_json = wezterm.home_dir .. "/.cache/wal/colors.json"

-- 이 줄이 핵심이다. wezterm 은 자기 설정 파일만 감시하므로, 캐시를 목록에
-- 넣어 두지 않으면 wal 을 돌려도 이미 열려 있는 창은 옛 색 그대로다.
wezterm.add_to_config_reload_watch_list(wal_json)

local function read_wal()
	local f = io.open(wal_json, "r")
	if not f then
		return nil
	end
	local body = f:read("*a")
	f:close()
	-- json_parse 는 깨진 파일에 에러를 던진다. wal 이 쓰는 도중에 읽으면
	-- 실제로 반쪽짜리 JSON 을 잡을 수 있고, 그때 설정 전체가 무효가 되는 것보다
	-- 색만 포기하는 편이 낫다.
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

-- ── 폰트 ──────────────────────────────────────────────────────────────────
-- ghostty 쪽과 같은 얼굴을 쓴다. D2Coding 은 한글 셀이 라틴의 정확히 두 배라
-- 한영을 섞어도 열이 안 밀린다 — 자세한 건 modules/shared/fonts.nix.
config.font = wezterm.font_with_fallback({
	"JetBrainsMono Nerd Font",
	"D2CodingLigature Nerd Font",
	"Apple Color Emoji",
})
config.font_size = 14.0

-- ── 창 ────────────────────────────────────────────────────────────────────
-- 타일링 WM 밑이라 타이틀바는 자리만 차지한다. RESIZE 는 테두리를 남겨서
-- 플로팅으로 띄웠을 때 마우스로 크기를 잡을 수 있게 한다.
config.window_decorations = "RESIZE"
config.window_padding = { left = 8, right = 8, top = 6, bottom = 6 }
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.adjust_window_size_when_changing_font_size = false

-- macOS 에서 왼쪽 Option 은 rift 의 수정자다(modules/darwin/config/rift.toml).
-- 여기서 Alt 로 잡아 버리면 alt-h 같은 바인딩이 터미널에 먹혀서 창 전환이 안
-- 된다. 오른쪽 Option 은 조판 문자용으로 남겨 둔다.
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = true

config.scrollback_lines = 10000
config.audible_bell = "Disabled"

return config
