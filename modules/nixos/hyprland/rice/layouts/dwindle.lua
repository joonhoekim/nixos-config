-- dwindle — 화면 하나를 이진 분할로 쪼개 가는 전통적인 BSP 타일링. 창은 늘 화면
-- 안에 있고 새 창은 활성 창의 자리를 반으로 쪼개고 들어온다. 작은 화면에서
-- 창을 둘 셋만 띄울 때 띠보다 손에 붙고, 니리와 갈리는 대가는 감수하는 쪽이다.
--
-- 스크롤링과 같은 자리를 다른 뜻으로 쓴다. 방향 티어의 J/L 은 트리에서 그 방향의
-- 이웃을 잡고(감싸 돌지 않는다), 컬럼 폭 자리는 창 크기, 컬럼 합치기 자리는
-- 그룹이다. 소유하는 키의 집합이 scrolling.lua 와 같지 않아도 된다 —
-- apps/rice/layout 이 옛 파일이 걸었던 키를 전부 풀고 이 파일을 돌린다.
--
-- 값 옆의 @ 표시는 스튜디오 손잡이 선언이다(scrolling.lua 머리말).

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
-- 네 방향 전부 평범한 방향 포커스다. 컬럼이 없으니 트리에서 그 방향의 이웃을
-- 잡는다. 끝에서 감싸 돌지 않고, 옆 모니터로는 새지 않는다. I/K 는 두 레이아웃이
-- 같아서 hyprland.lua 에 있다.
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "r" }))

-- 분할 트리 손대기. 스크롤링엔 없던 자리고, dwindle 전용 layoutmsg 다
-- (이름은 바이너리에서 확인: togglesplit swapsplit preselect movetoroot).
--   togglesplit   활성 창이 속한 분할의 방향을 뒤집는다(좌우 ↔ 상하).
--                 위의 preserve_split 이 꺼져 있으면 곧 되돌아간다.
--   swapsplit     그 분할의 두 쪽 자리를 맞바꾼다.
--   movetoroot    활성 창을 트리의 뿌리로 올린다 — 화면 절반을 혼자 차지한다.
--   pseudo        타일 자리는 그대로 둔 채 창을 제 크기로만 그린다(layoutmsg 가
--                 아니라 window 디스패처). 제 크기를 고집하는 다이얼로그용.
-- T 는 Tree, R 은 Root, P 는 Pseudo. Mod+R 은 스크롤링에서 폭 프리셋 순환
-- (니리의 switch-preset-column-width) 자리인데 dwindle 엔 그 개념이 없다.
-- Mod+C(fit_into_view)도 같은 이유로 없다 — 여기선 창이 화면 밖으로 안 나간다.
hl.bind(mod .. " + T", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + SHIFT + T", hl.dsp.layout("swapsplit"))
hl.bind(mod .. " + R", hl.dsp.layout("movetoroot"))
hl.bind(mod .. " + P", hl.dsp.window.pseudo())

-- 크기. 활성 창을 가로로 40px 씩 상대 조절한다 — 분할 비율이 따라 움직여서
-- 이웃도 같이 줄고 는다. 스크롤링의 colresize 는 컬럼 폭 비율(0.1)이다.
-- 인자 모양은 { x, y, relative?, window? } (바이너리의 에러 문구).
hl.bind(mod .. " + equal", hl.dsp.window.resize({ x = 40, y = 0, relative = true }))
hl.bind(mod .. " + minus", hl.dsp.window.resize({ x = -40, y = 0, relative = true }))

------------------------------------------------------------------------
-- 티어 2 — Mod+SHIFT: 창을 데리고 간다 (트리 안에서)
------------------------------------------------------------------------
-- 네 방향 모두 window.move 다(스크롤링의 J/L 은 swapcol). dwindle 의 move 는
-- 이웃과 자리를 맞바꾸는 게 아니라 트리에서 그쪽으로 옮겨 심는 것이라 결과
-- 모양이 매번 같지는 않다. 단순히 두 창의 자리만 바꾸고 싶으면
-- hl.dsp.window.swap({ direction = "l" }) 이다.
hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))

------------------------------------------------------------------------
-- 티어 3 — Mod+CTRL: WM 에게 말한다
------------------------------------------------------------------------
-- 이웃과 합치기 / 떼기 자리(rift 의 consume_or_expel_window, 니리의
-- consume-or-expel-window-right). 스크롤링에서는 컬럼에 쌓는 일이고, dwindle 엔
-- 컬럼이 없다. 가장 가까운 것은 **그룹**이다: 창 여럿을 타일 자리 하나에 탭으로
-- 겹쳐 두는 것. 이 키는 활성 창을 그룹으로 만들거나 푼다.
--
-- 다른 창을 그 그룹에 넣는 건 마우스로 탭바에 끌어다 놓는 것이고
-- (group:drag_into_group 기본값), 키로 하려면
-- hl.dsp.window.move({ into_group = "l"/"r"/"u"/"d" }) 인데 아직 안 걸었다.
-- 탭 사이는 아래 bracket 두 키다. 그룹 안에서도 Mod+I/K 같은 방향 포커스는
-- 그룹 밖 이웃으로 간다.
hl.bind(mod .. " + CTRL + E", hl.dsp.group.toggle())
hl.bind(mod .. " + bracketleft", hl.dsp.group.prev())
hl.bind(mod .. " + bracketright", hl.dsp.group.next())
