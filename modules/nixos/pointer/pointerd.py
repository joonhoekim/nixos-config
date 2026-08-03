#!/usr/bin/env python3
"""pointerd — the pointer half of the Caps Lock layer.

keyd owns the layer (see ../keyboard.nix) but cannot move a pointer. Its
vocabulary tops out at mouse *buttons* and wheel clicks: of the 319 key names
it knows, `leftmouse`, `middlemouse`, `rightmouse` and `scroll{up,down,left,
right}` are the whole mouse story, and no action in it emits REL_X/REL_Y. So
the layer maps the mouse keys to spare F-keys and this daemon turns them into
motion.

  reads   "keyd virtual keyboard", keyd's own output device, ungrabbed. The
          sentinels therefore reach applications too, and the high F-keys are
          not as inert as they look: the stock `us` keymap hands F13-F18 the
          XF86Tools and XF86Launch5-9 symbols, F20 XF86AudioMicMute, F21-F23
          the touchpad toggles, and leaves only F19 and F24 plain. F20 was in
          the first draft and toggled the microphone every time the middle
          button was pressed, because niri binds XF86AudioMicMute
          (../niri/rice/config.kdl). The set below is what nothing on this
          machine binds, with the two plain keys spent on the buttons that get
          pressed most; before moving one, check what it actually is:

              xkbcli compile-keymap --layout us | grep FK
  writes  one uinput pointer of its own. Motion, wheel and buttons all leave
          through that single device, so "hold 8, steer with wasd" arrives as
          one coherent drag rather than two devices racing.

Shift is read here rather than expressed as a keyd `[nav+shift]` composite
layer, because keyd resolves a binding when the key goes down: a composite
layer cannot slow down a `w` that is already held. Watching the shift key
directly makes the switch land mid-motion, which is the point of having it.

Runs as root under systemd (it needs /dev/input and /dev/uinput). To try
different numbers, stop the unit and run this file by hand — the constants
below are the whole tuning surface:

    sudo systemctl stop pointerd
    sudo $(nix build --no-link --print-out-paths \
             --impure --expr 'with import <nixpkgs> {}; \
                              python3.withPackages (ps: [ ps.evdev ])' \
          )/bin/python3 modules/nixos/pointer/pointerd.py
"""

import math
import selectors
import time

from evdev import InputDevice, UInput, ecodes as ec, list_devices

KEYD_DEVICE = "keyd virtual keyboard"
TICK = 1 / 125  # seconds between motion steps, while a key is held

# --- tuning ---------------------------------------------------------------
#
# Flat speeds, no acceleration curve. There was one here (200 -> 1800 px/s
# over 400ms) and it was dropped for two reasons: Karabiner's `mouse_key` on
# the macOS side cannot ramp at all, so keeping it meant the same layer
# behaving differently depending on which machine you sat at — and once it was
# actually used, the ramp did not earn that cost. Two flat speeds a Shift
# apart cover both jobs, and they are predictable, which turns out to be worth
# more than being fast.

MOVE_FAST = 700.0  # px/s
MOVE_SLOW = 100.0  # px/s while Shift is held, for aiming

SCROLL_RATE = 15.0  # wheel clicks/s

# A sentinel that never comes back up would fly the pointer off the screen or
# leave a button stuck down, and this process runs as root with a synthetic
# pointer — so it refuses to believe in holds longer than these. Neither is a
# length any of these keys is legitimately held for.
STUCK_MOVE = 15.0
STUCK_BUTTON = 60.0

# --- the layer's mouse keys -----------------------------------------------

MOVE = {                       # sentinel -> direction, unit vector
    ec.KEY_F13: (0.0, -1.0),   # w
    ec.KEY_F14: (-1.0, 0.0),   # a
    ec.KEY_F15: (0.0, 1.0),    # s
    ec.KEY_F16: (1.0, 0.0),    # d
}

SCROLL = {                     # sentinel -> (unshifted, shifted) sign
    ec.KEY_F17: (1, -1),       # q: wheel up   / Shift: scroll left
    ec.KEY_F18: (-1, 1),       # e: wheel down / Shift: scroll right
}

BUTTONS = {
    ec.KEY_F19: ec.BTN_LEFT,    # f and 8 — F19 is a plain symbol
    ec.KEY_F22: ec.BTN_MIDDLE,  # 9       — XF86TouchpadOn, unbound here
    ec.KEY_F24: ec.BTN_RIGHT,   # r and 0 — F24 is a plain symbol
}

SHIFT = {ec.KEY_LEFTSHIFT, ec.KEY_RIGHTSHIFT}

CAPS = {
    ec.EV_KEY: [ec.BTN_LEFT, ec.BTN_MIDDLE, ec.BTN_RIGHT],
    ec.EV_REL: [ec.REL_X, ec.REL_Y, ec.REL_WHEEL, ec.REL_HWHEEL],
}


class Pointer:
    """Held sentinels in, relative motion out."""

    def __init__(self, ui):
        self.ui = ui
        self.held = {}  # sentinel code -> monotonic time it went down
        self.shift = False
        self.acc_x = 0.0
        self.acc_y = 0.0
        self.acc_wheel = 0.0

    # -- input --

    def key(self, code, down, now):
        if code in SHIFT:
            self.shift = down
        elif code in BUTTONS:
            if down:
                self.held[code] = now
                self.ui.write(ec.EV_KEY, BUTTONS[code], 1)
                self.ui.syn()
            else:
                self.release(code)
        elif code in MOVE or code in SCROLL:
            if down:
                self.held[code] = now
            else:
                self.held.pop(code, None)

    def release(self, code):
        """Let go of a sentinel, and of the button it was holding down."""
        self.held.pop(code, None)
        if code in BUTTONS:
            self.ui.write(ec.EV_KEY, BUTTONS[code], 0)
            self.ui.syn()

    def release_all(self):
        for code in list(self.held):
            self.release(code)

    # -- output --

    def step(self, dt, now):
        for code, t0 in list(self.held.items()):
            limit = STUCK_BUTTON if code in BUTTONS else STUCK_MOVE
            if now - t0 > limit:
                self.release(code)

        moved = self._move(dt)
        scrolled = self._scroll(dt)
        if moved or scrolled:
            self.ui.syn()

    def _move(self, dt):
        x = y = 0.0
        for code in self.held:
            if code in MOVE:
                dx, dy = MOVE[code]
                x += dx
                y += dy

        # Opposing keys cancel out, and so does an empty hand.
        if x == 0.0 and y == 0.0:
            self.acc_x = self.acc_y = 0.0
            return False

        speed = MOVE_SLOW if self.shift else MOVE_FAST

        # Normalised, so w+d travels at the same speed as w alone rather than
        # sqrt(2) times faster.
        norm = math.hypot(x, y)
        self.acc_x += speed * dt * x / norm
        self.acc_y += speed * dt * y / norm

        # Whole pixels go out, the fraction stays behind — at 125 Hz the
        # per-tick step is often < 1 px and truncating it would stall.
        step_x = int(self.acc_x)
        step_y = int(self.acc_y)
        self.acc_x -= step_x
        self.acc_y -= step_y
        if step_x:
            self.ui.write(ec.EV_REL, ec.REL_X, step_x)
        if step_y:
            self.ui.write(ec.EV_REL, ec.REL_Y, step_y)
        return bool(step_x or step_y)

    def _scroll(self, dt):
        direction = 0
        for code in self.held:
            if code in SCROLL:
                direction += SCROLL[code][1 if self.shift else 0]

        if direction == 0:
            self.acc_wheel = 0.0
            return False

        self.acc_wheel += SCROLL_RATE * dt * (1 if direction > 0 else -1)
        clicks = int(self.acc_wheel)
        self.acc_wheel -= clicks
        if not clicks:
            return False
        axis = ec.REL_HWHEEL if self.shift else ec.REL_WHEEL
        self.ui.write(ec.EV_REL, axis, clicks)
        return True


def find_keyd():
    """Wait for keyd's virtual keyboard to exist, then return it."""
    while True:
        for path in list_devices():
            try:
                dev = InputDevice(path)
            except OSError:
                continue
            if dev.name == KEYD_DEVICE:
                return dev
            dev.close()
        time.sleep(1.0)


def pump(dev, pointer):
    """Follow one device until it goes away."""
    sel = selectors.DefaultSelector()
    sel.register(dev, selectors.EVENT_READ)
    last = time.monotonic()
    try:
        while True:
            # Tick only while a sentinel is down. With an empty hand there is
            # nothing to integrate, so block until the next key event rather
            # than wake 125 times a second to decide that — and an empty hand
            # is what this process has for all but a few minutes of the day.
            # The wakeups cost more by keeping the CPU out of its deep sleep
            # states than they do in CPU time, which is the part that shows up
            # on a laptop battery.
            sel.select(TICK if pointer.held else None)
            try:
                for event in dev.read():
                    if event.type == ec.EV_KEY and event.value != 2:
                        pointer.key(event.code, event.value == 1,
                                    time.monotonic())
            except BlockingIOError:
                pass
            now = time.monotonic()
            # Clamped, because the first tick after an idle block — or after a
            # suspend/resume — would otherwise integrate the whole gap at once
            # and fling the pointer off the screen.
            pointer.step(min(now - last, TICK * 4), now)
            last = now
    finally:
        sel.close()


def main():
    ui = UInput(CAPS, name="pointerd virtual pointer")
    pointer = Pointer(ui)
    try:
        while True:
            dev = find_keyd()
            try:
                pump(dev, pointer)
            except OSError:
                pass  # keyd restarted and took its device with it
            finally:
                # Whatever was held is not held any more, and nothing else
                # will ever send the key-up for it.
                pointer.release_all()
                try:
                    dev.close()
                except OSError:
                    pass
    finally:
        pointer.release_all()
        ui.close()


if __name__ == "__main__":
    main()
