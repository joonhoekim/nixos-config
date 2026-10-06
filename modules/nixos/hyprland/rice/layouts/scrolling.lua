-- 스크롤링 — 니리와 같은 무한 띠. 컬럼이 오른쪽으로 끝없이 쌓이고 화면은 그 위를
-- 미는 창이라, 창이 화면 밖에 살 수 있다. 두 세션을 오가며 쓸 때 근육기억이
-- 갈리지 않는 쪽이고, 그래서 기본값이다.
--
-- ── 이 파일이 소유하는 것 ─────────────────────────────────────────────────
-- general.layout, 그 레이아웃의 값 블록, 그리고 **레이아웃마다 뜻이 달라지는
-- 키**들이다. 방향·워크스페이스·모니터 티어 자체는 ../hyprland.lua 에 있고 여기
-- 없다 — 레이아웃이 바뀌어도 그 키들은 그대로다. 여기 있는 것은 "컬럼"이라는
-- 개념이 있어야만 뜻이 서는 키들이고, dwindle.lua 는 같은 키에 트리 조작을 건다.
--
-- 어느 파일을 읽을지는 ~/.config/rice/layout 한 줄이 정하고(없으면 이것),
-- 갈아끼우는 것은 apps/rice/layout 이다 — 리로드 없이 옛 파일의 키를 풀고 이
-- 파일을 다시 돌린다. 그래서 이 파일은 **몇 번을 다시 돌려도 같은 결과**여야
-- 한다: 상태를 쌓지 말고, 걸 것을 선언만 한다.
--
-- ── 값 옆의 @ 표시는 슬라이더 선언이다 ────────────────────────────────────
-- `-- @0.2..0.9:0.05 설명` 이 붙은 값만 라이싱 스튜디오의 「배치」탭에 손잡이로
-- 뜬다(apps/rice/layout 이 읽고 쓴다). 셰이더의 `// @범위` 와 같은 규약이고,
-- 설명은 바로 위 주석 덩어리와 범위 뒤의 글자를 쓴다. 문자열 값에는 못 단다.

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
        -- 니리의 preset-column-widths. Mod+R 이 이 목록을 순환한다. 문자열이라
        -- 손잡이는 없다 — 고치려면 여기서.
        explicit_column_widths = "0.333, 0.5, 0.667",
        -- 1 = 포커스한 컬럼을 최소한으로만 끌어와 화면에 넣는다(니리의 기본
        -- 동작). 0 이면 매번 가운데로 끌어온다 — 그건 Mod+C 로 따로 준다.
        focus_fit_method = 1, -- @0..1
    },
})

------------------------------------------------------------------------
-- 티어 1 — Mod: 간다 (컬럼 사이)
------------------------------------------------------------------------
-- 컬럼 사이(J/L)는 layout 메시지로 간다 — 끝에서 감싸 돌고, 옆 모니터로 새지
-- 않는다. 컬럼 *안*의 위아래(I/K)는 평범한 방향 포커스라 hyprland.lua 에 있다.
hl.bind(mod .. " + J", hl.dsp.layout("focus l"))
hl.bind(mod .. " + L", hl.dsp.layout("focus r"))
hl.bind(mod .. " + left", hl.dsp.layout("focus l"))
hl.bind(mod .. " + right", hl.dsp.layout("focus r"))

-- 니리의 focus-column-first/last 를 Mod+Home/End 로 옮겨 뒀었지만 둘 다 죽은
-- 바인드였다. focus 의 `window` 는 위치 키워드가 아니라 창 셀렉터(class:, title:,
-- address:)라서 "first"/"last" 는 아무것도 못 찾고 경고만 찍는다. 스크롤링
-- 레이아웃에 끝 컬럼으로 뛰는 메시지도 없다 — layoutmsg("focus ...") 는 첫 글자만
-- 방향으로 읽어서 leftmost/rightmost/last 가 전부 l/r 과 똑같이 한 칸만 가고,
-- 그 한 칸은 끝에서 감싸 돌기까지 한다. 되살리려면 hl.get_windows() 로 컬럼을
-- 직접 훑는 함수를 써야 하고, 동작을 확인한 형태가 docs/hyprland-binds.md 에 있다.

-- 니리의 center-column 자리. 정확히 같지는 않다 — 이건 활성 컬럼을 화면 안에
-- 완전히 넣는 것이고, 가운데 정렬은 위의 focus_fit_method 가 정한다.
hl.bind(mod .. " + C", hl.dsp.layout("fit_into_view"))

-- 컬럼 폭
hl.bind(mod .. " + equal", hl.dsp.layout("colresize +0.1"))
hl.bind(mod .. " + minus", hl.dsp.layout("colresize -0.1"))
-- 니리의 switch-preset-column-width. 목록은 위 explicit_column_widths 다.
-- rift 에는 이 동작이 아예 없어서 그쪽은 같은 키에 monocle 스크립트가 걸린다.
hl.bind(mod .. " + R", hl.dsp.layout("colresize +conf"))

------------------------------------------------------------------------
-- 티어 2 — Mod+SHIFT: 창을 데리고 간다 (컬럼 사이)
------------------------------------------------------------------------
-- 컬럼째로 자리를 맞바꾼다. 위아래(SHIFT+I/K)는 컬럼 안에서의 창 이동이라
-- hyprland.lua 에 있다.
hl.bind(mod .. " + SHIFT + J", hl.dsp.layout("swapcol l"))
hl.bind(mod .. " + SHIFT + L", hl.dsp.layout("swapcol r"))
hl.bind(mod .. " + SHIFT + left", hl.dsp.layout("swapcol l"))
hl.bind(mod .. " + SHIFT + right", hl.dsp.layout("swapcol r"))

------------------------------------------------------------------------
-- 티어 3 — Mod+CTRL: WM 에게 말한다
------------------------------------------------------------------------
-- 이웃과 합치기 / 떼기. rift 의 Mod+Ctrl+E(consume_or_expel_window)와 니리의
-- consume-or-expel-window-right 자리다. 세 WM 에서 같은 키가 같은 일을 한다.
--
-- 하이프랜드에는 그 하나짜리 액션이 없다. layoutmsg 로 쪼개져 있고, 둘 중 뭘
-- 부를지는 지금 상태를 보고 여기서 정해야 한다:
--
--   consume   다음 컬럼의 맨 위 창 하나를 이 컬럼으로 끌어온다
--   promote   활성 창을 컬럼에서 빼내 바로 오른쪽에 새 컬럼으로 둔다
--
-- **`expel` 이 아니라 `promote` 다.** 이름은 expel 이 짝처럼 보이지만, 그건
-- 포커스가 어디 있든 컬럼 **맨 아래** 창을 뱉는다(니리 문서도 expel-window-
-- from-column 을 "the bottom window" 라고 적는다). 골라서 빼내는 건 promote 뿐
-- 이다. 좌표를 재서 확인했다 — docs/hyprland-binds.md 의 layoutmsg 표.
--
-- 컬럼 판별은 x 좌표다. 같은 컬럼의 창들은 x 가 정확히 같고 컬럼끼리는 다르다.
-- 띄운 창은 이 계산에서 빼야 아무 데나 걸쳐 있는 플로팅 하나가 판정을 뒤집지
-- 않는다.
--
-- 왕복이 완전하지는 않다. promote 로 나간 창은 맨 오른쪽 컬럼이 되므로 다시
-- 누르면 `no next column` 이다 — 가져올 다음 컬럼이 없으니 맞는 대답이다.
-- 되돌리려면 왼쪽 컬럼을 잡고 누르면 된다. 니리의 방향성도 같다.
hl.bind(mod .. " + CTRL + E", function()
    local act = hl.get_active_window()
    if not act or act.floating then return end
    local siblings = 0
    for _, w in ipairs(hl.get_workspace_windows(act.workspace)) do
        if not w.floating and w.at.x == act.at.x then siblings = siblings + 1 end
    end
    hl.dispatch(hl.dsp.layout(siblings > 1 and "promote" or "consume"))
end)
