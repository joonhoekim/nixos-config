-- 스크롤링 — 니리와 같은 무한 띠. 컬럼이 오른쪽으로 끝없이 쌓이고 화면은 그 위를
-- 미는 창이라, 창이 화면 밖에 살 수 있다. 두 세션을 오가며 쓸 때 근육기억이
-- 갈리지 않는 쪽이고, 그래서 기본값이다.
--
-- 레이아웃마다 뜻이 다른 키만 소유한다. apps/rice/layout 이 리로드 없이 다시 돌리므로 상태를 쌓지 않는다.
-- 값 옆 `-- @범위` 는 스튜디오 손잡이 선언이고, 머리말 첫 덩어리와 바로 위 주석이 그 설명으로 뜬다.

local mod = "SUPER"

hl.config({
    general = {
        layout = "scrolling",
    },

    -- 값은 니리 config.kdl 의 layout 블록에서 옮겨왔다.
    scrolling = {
        -- ── 컬럼 ──────────────────────────────────────────────────────────
        -- 니리의 default-column-width. 새 컬럼이 화면의 얼마를 차지하고 뜨는가.
        column_width = 0.5, -- @0.25..0.9:0.05
        -- 니리의 preset-column-widths. Mod+R 이 순환한다. 문자열이라 손잡이가 없다.
        explicit_column_widths = "0.333, 0.5, 0.667",
        -- 1 = 포커스한 컬럼을 최소한으로만 끌어와 화면에 넣는다(니리의 기본
        -- 동작). 0 이면 매번 가운데로 끌어온다 — 그건 Mod+C 로 따로 준다.
        focus_fit_method = 1, -- @0..1
    },
})

------------------------------------------------------------------------
-- 티어 1 — Mod: 간다 (컬럼 사이)
------------------------------------------------------------------------
-- layout("focus …") 는 포인터 포커스를 다시 잡지 않아, 마우스를 안 움직이고 클릭하면 옛 창이 포커스를
-- 도로 가져간다(VS Code·Chrome 의 서브서피스). 커서를 제자리로 move 해 다시 잡게 한다.
-- docs/postmortems/2026-10-13-hyprland-click-after-keyboard-focus.md
local function focus_column(dir)
    return function()
        hl.dispatch(hl.dsp.layout("focus " .. dir))
        local p = hl.get_cursor_pos()
        hl.dispatch(hl.dsp.cursor.move({ x = p.x, y = p.y }))
    end
end
hl.bind(mod .. " + J", focus_column("l"))
hl.bind(mod .. " + L", focus_column("r"))
hl.bind(mod .. " + left", focus_column("l"))
hl.bind(mod .. " + right", focus_column("r"))

-- focus-column-first/last 는 없다 — 끝 컬럼으로 뛰는 메시지가 없다(되살리는 법: docs/hyprland-binds.md).

-- 니리의 center-column 과 다르다: 화면 안에 넣기만 하고, 가운데 정렬은 focus_fit_method 가 정한다.
hl.bind(mod .. " + C", hl.dsp.layout("fit_into_view"))

hl.bind(mod .. " + equal", hl.dsp.layout("colresize +0.1"))
hl.bind(mod .. " + minus", hl.dsp.layout("colresize -0.1"))
-- 니리의 switch-preset-column-width.
hl.bind(mod .. " + R", hl.dsp.layout("colresize +conf"))

------------------------------------------------------------------------
-- 티어 2 — Mod+SHIFT: 창을 데리고 간다 (컬럼 사이)
------------------------------------------------------------------------
hl.bind(mod .. " + SHIFT + J", hl.dsp.layout("swapcol l"))
hl.bind(mod .. " + SHIFT + L", hl.dsp.layout("swapcol r"))
hl.bind(mod .. " + SHIFT + left", hl.dsp.layout("swapcol l"))
hl.bind(mod .. " + SHIFT + right", hl.dsp.layout("swapcol r"))

------------------------------------------------------------------------
-- 티어 3 — Mod+CTRL: WM 에게 말한다
------------------------------------------------------------------------
-- 합치기/떼기. `expel` 은 포커스와 무관하게 맨 아래 창을 뱉어서 `promote` 를 쓴다(docs/hyprland-binds.md).
-- 같은 컬럼은 x 가 정확히 같다. 띄운 창은 판정을 뒤집지 않게 뺀다.
hl.bind(mod .. " + CTRL + E", function()
    local act = hl.get_active_window()
    if not act or act.floating then return end
    local siblings = 0
    for _, w in ipairs(hl.get_workspace_windows(act.workspace)) do
        if not w.floating and w.at.x == act.at.x then siblings = siblings + 1 end
    end
    hl.dispatch(hl.dsp.layout(siblings > 1 and "promote" or "consume"))
end)
