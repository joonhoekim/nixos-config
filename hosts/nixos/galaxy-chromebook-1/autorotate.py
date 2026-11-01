"""화면 회전 데몬. iio-sensor-proxy 를 읽고 `hyprctl eval` 로 하이프랜드를 돌린다.

iio-hyprland 가 아닌 이유: 그쪽의 `hyprctl keyword` 를 0.56 의 Lua 설정이 종료 코드 0 으로 거부한다.
파이썬인 이유: ClaimAccelerometer 는 부른 DBus 커넥션이 사는 동안만 유효하다. 자세히: docs/galaxy-chromebook-1.md
"""

import signal
import subprocess
import sys

import gi

gi.require_version("Gio", "2.0")
gi.require_version("GLibUnix", "2.0")
from gi.repository import Gio, GLib, GLibUnix  # noqa: E402

MONITOR = "eDP-1"
STATE = None  # touch.nix 가 인자로 준다

# 하이프랜드 transform 0/1/2/3 = Normal/90/180/270. "undefined"(평평하게 눕힘)는 표에 없어서
# 마지막 방향을 그대로 둔다.
TRANSFORM = {
    "normal": 0,
    "left-up": 1,
    "bottom-up": 2,
    "right-up": 3,
}


def log(msg):
    """저널로 한 줄씩. TRANSFORM 표를 실기에서 맞출 때 `journalctl --user -fu hypr-autorotate`."""
    print(msg, file=sys.stderr, flush=True)


def apply(transform):
    """모니터와 입력을 한 번에 돌린다. 하이프랜드는 sway 와 달리 매핑된 입력을 따라 돌리지 않아,
    모니터만 돌리면 터치가 90도 어긋난 곳을 누른다.
    """
    lua = (
        f'hl.monitor({{ output = "{MONITOR}", transform = {transform} }}) '
        f"hl.config({{ input = {{ "
        f"touchdevice = {{ transform = {transform} }}, "
        f"tablet = {{ transform = {transform} }} }} }})"
    )
    subprocess.run(["hyprctl", "eval", lua], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


class Rotator:
    def __init__(self, proxy, state_path):
        self.proxy = proxy
        self.state_path = state_path
        self.enabled = False
        self.write_state()

    def write_state(self):
        # CLI 의 `status` 가 읽는 자리. 데몬만 쓴다.
        try:
            self.state_path.replace_contents(
                b"on\n" if self.enabled else b"off\n",
                None, False, Gio.FileCreateFlags.REPLACE_DESTINATION, None)
        except GLib.Error:
            pass

    def orientation(self):
        v = self.proxy.get_cached_property("AccelerometerOrientation")
        return v.get_string() if v else "undefined"

    def sync(self):
        """지금 방향을 화면에 반영한다. 꺼져 있으면 정방향으로 되돌린다."""
        if not self.enabled:
            apply(0)
            log("off -> transform 0")
            return
        o = self.orientation()
        t = TRANSFORM.get(o)
        if t is None:
            log(f"{o} -> 그대로 둠")
            return
        apply(t)
        log(f"{o} -> transform {t}")

    def on_props(self, _proxy, changed, _invalidated):
        if "AccelerometerOrientation" in changed.keys():
            self.sync()

    def set(self, enabled):
        self.enabled = enabled
        self.write_state()
        self.sync()


def main():
    state_path = Gio.File.new_for_path(sys.argv[1])

    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    proxy = Gio.DBusProxy.new_sync(
        bus, Gio.DBusProxyFlags.NONE, None,
        "net.hadess.SensorProxy", "/net/hadess/SensorProxy",
        "net.hadess.SensorProxy", None)

    # 이 호출이 센서 폴링을 켠다. 안 부르면 AccelerometerOrientation 은
    # 영원히 마지막 값에 머물고, PropertiesChanged 도 안 온다.
    proxy.call_sync("ClaimAccelerometer", None, Gio.DBusCallFlags.NONE, -1, None)

    rot = Rotator(proxy, state_path)
    proxy.connect("g-properties-changed", rot.on_props)

    loop = GLib.MainLoop()

    # 신호는 GLib 으로 받는다. 파이썬 핸들러는 GLib poll 안에서 몇 초씩 늦는다. GLibUnix.signal_add 는
    # SIGHUP/INT/TERM/USR1/USR2/WINCH 밖의 신호엔 핸들러를 조용히 안 걸어서 SIGRTMIN 을 못 쓰고,
    # 그래서 autorotate CLI 의 toggle 은 상태 파일을 읽는다.
    for sig, fn in ((signal.SIGUSR2, lambda: rot.set(True)),
                    (signal.SIGUSR1, lambda: rot.set(False))):
        GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, sig,
                            lambda f=fn: (f(), True)[1])

    loop.run()


if __name__ == "__main__":
    main()
