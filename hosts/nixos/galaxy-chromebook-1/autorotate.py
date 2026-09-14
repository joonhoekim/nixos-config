"""화면 회전 데몬. iio-sensor-proxy 를 읽고 하이프랜드를 돌린다.

./touch.nix 가 systemd user service 로 띄우고, `autorotate` CLI 가 신호로
켜고 끈다. 신호 규약은 같은 파일의 `osk` 와 맞춰 뒀다 — USR2 켜기, USR1 끄기,
RTMIN 토글.

── 왜 iio-hyprland 가 아닌가 ────────────────────────────────────────────────
nixpkgs 에 있고 하는 일도 정확히 이것인데, **이 설정에서는 한 줄도 안 먹는다.**
그쪽은 전부 `hyprctl keyword` 로 말하고, 하이프랜드 0.56 은 Lua 설정에서 그걸
거부한다:

    $ hyprctl keyword input:touchdevice:transform 0
    keyword can't work with non-legacy parsers. Use eval.

거부는 하되 **종료 코드는 0** 이라, 그쪽 데몬은 자기가 실패한 줄 모르고 계속
돈다. 증상은 "서비스는 active 인데 화면이 안 돈다" 하나뿐이다. 그래서 같은 일을
`hyprctl eval` 로 다시 쓴다.

── 왜 가속도계를 직접 안 읽는가 ─────────────────────────────────────────────
/sys/bus/iio 에 accel-display / accel-base 두 개가 그대로 있어서 raw 값을 읽고
각도를 푸는 길도 있다. 안 하는 이유는 마운트 행렬 때문이다 — 센서가 패널에 어느
방향으로 붙어 있는지는 펌웨어가 알려주는 값이고, iio-sensor-proxy 는 그걸 읽어
방향 문자열까지 풀어 준다. 직접 풀면 그 보정을 다시 구현해야 하고, 틀렸을 때
증상은 "90도씩 어긋나게 돈다" 라 값을 눈으로 맞출 때까지 모른다.

── 클레임은 커넥션에 묶인다 ─────────────────────────────────────────────────
ClaimAccelerometer 는 부른 **DBus 커넥션**이 살아 있는 동안만 유효하다. 셸에서
`busctl call` 로 부르면 그 프로세스가 끝나는 순간 릴리즈되고, 그러면
iio-sensor-proxy 는 센서 폴링을 멈춘다(전력 때문이다). 그래서 이 파일이 파이썬
데몬인 것이고, 셸 스크립트로는 이 한 가지를 못 한다.
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

# iio-sensor-proxy 의 방향 문자열 -> 하이프랜드 transform.
# 하이프랜드의 0/1/2/3 은 Normal / 90 / 180 / 270 이고, wlroots 계열이 전부
# 같은 뜻으로 쓴다. "undefined" 는 표에 없다 — 평평하게 눕혀서 센서가 판단을
# 못 하는 상태이고, 그때는 마지막 방향을 그대로 둔다.
TRANSFORM = {
    "normal": 0,
    "left-up": 1,
    "bottom-up": 2,
    "right-up": 3,
}


def log(msg):
    """저널로 나간다. 방향 하나가 한 줄이다.

    켜 두는 값어치는 위 TRANSFORM 표를 실기에서 맞출 때 나온다 — 화면이 엉뚱한
    쪽으로 돌면 `journalctl --user -fu hypr-autorotate` 가 어느 방향 문자열에
    어느 각도를 줬는지 그대로 보여주고, 고칠 자리는 그 표 한 곳이다.
    """
    print(msg, file=sys.stderr, flush=True)


def apply(transform):
    """모니터와 입력 장치를 같은 각도로 돌린다.

    셋을 한 번에 보내는 것이 요점이다. 하이프랜드는 출력이 돌아갈 때 거기
    매핑된 입력을 따라 돌려주지 **않는다**(sway 와 다른 점이다). 모니터만
    돌리면 화면은 세로인데 터치는 가로로 남아서, 찍은 자리에서 90도 떨어진
    곳이 눌린다.
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
            # "undefined" — 평평하게 눕혔다. 마지막 방향을 그대로 둔다.
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

    # 신호는 GLib 을 통해 받는다. 파이썬의 signal 핸들러는 다음 바이트코드가
    # 돌아야 실행되는데, 이 프로세스는 대부분의 시간을 GLib 의 poll 안에서
    # 보내므로 신호가 몇 초씩 늦거나 다음 DBus 이벤트까지 안 온다.
    #
    # **USR1 과 USR2 뿐이다.** GLibUnix.signal_add 는 받는 신호가 정해져 있고
    # (SIGHUP/INT/TERM/USR1/USR2/WINCH), 그 밖의 것을 주면 assertion 을 찍고
    # 핸들러를 그냥 안 건다 — 서비스는 계속 도는데 그 신호만 조용히 사라진다.
    # `osk` 가 토글에 쓰는 SIGRTMIN 이 여기선 못 쓰이는 이유이고, 그래서
    # autorotate CLI 의 toggle 은 신호가 아니라 상태 파일을 읽어서 가른다.
    for sig, fn in ((signal.SIGUSR2, lambda: rot.set(True)),
                    (signal.SIGUSR1, lambda: rot.set(False))):
        GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, sig,
                            lambda f=fn: (f(), True)[1])

    loop.run()


if __name__ == "__main__":
    main()
