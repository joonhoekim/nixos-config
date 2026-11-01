-- dwindle — 화면 하나를 이진 분할로 쪼개 가는 전통적인 BSP 타일링. 창은 늘 화면
-- 안에 있고 새 창은 활성 창의 자리를 반으로 쪼개고 들어온다. 작은 화면에서
-- 창을 둘 셋만 띄울 때 띠보다 손에 붙고, 니리와 갈리는 대가는 감수하는 쪽이다.
--
-- 스크롤링과 같은 키 자리를 트리 조작에 쓴다. 값 옆 @ 는 스튜디오 손잡이 선언(scrolling.lua 머리말).

local mod = "SUPER"

hl.config({
    general = {
        layout = "dwindle",
    },

    -- 니리에서 옮겨올 값은 없다 — 그쪽엔 분할 트리가 없다.
    dwindle = {
        -- ── 분할 ──────────────────────────────────────────────────────────
        -- 한 번 정한 분할 방향을 지킨다. 기본(false)은 리레이아웃마다 창 모양을
        -- 보고 방향을 다시 정하므로, Mod+T(togglesplit)로 뒤집어 봤자 다음
        -- 창이 뜨는 순간 되돌아간다. 이게 켜져 있어야 그 키가 뜻을 가진다.
        preserve_split = true, -- @bool
        -- 0 = 창 모양대로(넓으면 좌우로, 높으면 상하로 쪼갠다). 1 은 항상 좌우,
        -- 2 는 항상 상하. 16:9 에서 0 은 사실상 "첫 분할은 좌우, 그 다음은 상하"다.
        force_split = 0, -- @0..2
        -- 새 창이 들어올 때 둘이 나눠 갖는 비율. 1.0 = 반반.
        default_split_ratio = 1.0, -- @0.1..1.9:0.05
    },
})

------------------------------------------------------------------------
-- 티어 1 — Mod: 간다 (트리 안에서)
------------------------------------------------------------------------
-- 트리 이웃으로 간다. 감싸 돌지 않는다.
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "r" }))

-- dwindle 전용 layoutmsg(이름은 바이너리에서 확인). T=Tree, R=Root, P=Pseudo.
-- Mod+C(fit_into_view)는 없다 — 여기선 창이 화면 밖으로 안 나간다.
hl.bind(mod .. " + T", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + SHIFT + T", hl.dsp.layout("swapsplit"))
hl.bind(mod .. " + R", hl.dsp.layout("movetoroot"))
hl.bind(mod .. " + P", hl.dsp.window.pseudo())

-- 분할 비율이 따라 움직여 이웃도 같이 변한다. 인자 모양 { x, y, relative?, window? } 는 바이너리의 에러 문구.
hl.bind(mod .. " + equal", hl.dsp.window.resize({ x = 40, y = 0, relative = true }))
hl.bind(mod .. " + minus", hl.dsp.window.resize({ x = -40, y = 0, relative = true }))

------------------------------------------------------------------------
-- 티어 2 — Mod+SHIFT: 창을 데리고 간다 (트리 안에서)
------------------------------------------------------------------------
-- dwindle 의 move 는 트리에 옮겨 심는 것이라 모양이 매번 같지 않다. 자리만 바꾸려면 window.swap.
hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))

------------------------------------------------------------------------
-- 티어 3 — Mod+CTRL: WM 에게 말한다
------------------------------------------------------------------------
-- 컬럼이 없어서 가장 가까운 그룹(탭)으로 대신한다. 다른 창은 탭바로 끌어다 넣는다(group:drag_into_group).
hl.bind(mod .. " + CTRL + E", hl.dsp.group.toggle())
hl.bind(mod .. " + bracketleft", hl.dsp.group.prev())
hl.bind(mod .. " + bracketright", hl.dsp.group.next())
