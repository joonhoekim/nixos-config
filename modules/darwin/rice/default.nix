{ config, pkgs, lib, user, ... }:

let
  # 벽지가 바뀌면 팔레트를 다시 뽑는 감시자. launchd.user.agents.wal-watch 가
  # 이걸 돌린다 — 왜 필요한지는 그 블록의 주석에.
  #
  # 실제 작업은 apps/rice-colors 가 한다. 여기서 wal 을 직접 부르지 않는 이유는,
  # "팔레트를 뽑고 소비자들에게 밀어 넣는" 절차가 두 벌이 되면 반드시 한쪽만
  # 고치는 날이 오기 때문이다. 손으로 부르든 감시자가 부르든 같은 파일이다.
  # 벽지 경로를 Index.plist 에서 직접 꺼낸다.
  #
  # ── 왜 osascript 가 아닌가 ─────────────────────────────────────────────
  # 처음엔 `osascript -e 'tell application "System Events" ... get picture'` 로
  # 짰다. 터미널에서는 잘 되는데 LaunchAgent 안에서는 빈 문자열만 돌아왔다 —
  # System Events 에 말을 거는 건 Automation 권한이 필요하고, 백그라운드 에이전트
  # 에게는 그 프롬프트가 뜨지 않기 때문이다. 거부도 아니고 응답 없음이라 로그조차
  # 안 남았다.
  #
  # plist 를 직접 읽으면 그냥 자기 홈의 파일이라 아무 권한도 필요 없다.
  #
  # 경로는 중첩된 바이너리 plist 안에 들어 있어서 plutil 로 한 겹 벗겨도 base64
  # 덩어리만 나온다. 그래서 파일을 바이트로 읽고 file:// URL 을 그대로 찾는다 —
  # 중첩이든 아니든 그 바이트열은 파일 어딘가에 반드시 평문으로 있다.
  #
  # 퍼센트 디코딩이 python 을 쓰는 이유다. 파일명에 공백이나 한글이 있으면 URL 은
  # %20 / %ED%95%9C 로 인코딩돼 있고, 그걸 안 풀면 "그런 파일 없다"로 끝난다.
  wallpaperPath = pkgs.writeShellScript "wallpaper-path" ''
    exec ${pkgs.python3}/bin/python3 -c '
import re, sys, urllib.parse
try:
    raw = open(sys.argv[1], "rb").read()
except OSError:
    sys.exit(1)
# [!-~] = 공백을 뺀 출력 가능 ASCII. URL 안의 공백은 %20 이므로 이걸로 끝을 잡는다.
m = re.search(rb"file:///[!-~]+", raw)
if not m:
    sys.exit(1)
url = urllib.parse.unquote(m.group().decode("utf-8", "replace"))
print(url[len("file://"):])
' "$1"
  '';

  walWatch = pkgs.writeShellScript "wal-watch" ''
    set -u

    plist="$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
    # 마지막으로 처리한 벽지. 이게 없으면 macOS 가 저 plist 를 건드릴 때마다
    # (벽지와 무관한 이유로도 쓴다) wal 이 통째로 다시 돈다.
    state="$HOME/.cache/wal/.last-wallpaper"

    apply() {
      img="$(${wallpaperPath} "$plist" 2>/dev/null || true)"

      # 실패는 반드시 말한다. 이 감시자는 아무도 안 보는 데서 도는 유일한 조각이라,
      # 조용히 죽으면 "색이 안 따라온다" 말고는 증상이 없다.
      if [ -z "$img" ]; then
        echo "벽지 경로를 못 읽었다: $plist"
        return 0
      fi
      if [ ! -f "$img" ]; then
        echo "벽지 파일이 없다: $img"
        return 0
      fi
      [ "$img" = "$(cat "$state" 2>/dev/null || true)" ] && return 0

      mkdir -p "$(dirname "$state")"
      printf '%s' "$img" > "$state"
      echo "wallpaper -> $img"
      ${../../../apps/rice-colors} "$img" || echo "rice-colors 실패"
    }

    # 로그인 직후 한 번. state 검사가 있으니 벽지가 그대로면 아무 일도 안 한다 —
    # 매 로그인마다 wal 을 돌리는 게 아니라, 로그인 사이에 바뀐 경우를 잡는다.
    apply

    # plist 가 아직 없는 새 계정. fswatch 는 없는 경로에 대고 바로 죽고, KeepAlive
    # 가 그걸 재시작 루프로 만든다. 생길 때까지 조용히 기다리는 편이 낫다.
    while [ ! -f "$plist" ]; do sleep 30; done

    # -o 는 "몇 건 바뀌었다"만 뱉는다. 어느 파일인지는 어차피 하나뿐이라 필요 없다.
    fswatch -o "$plist" | while read -r _; do
      apply
    done
  '';
in

# macOS ricing: the status bar, the window borders, and the colour generator
# that feeds both.
#
# The window manager itself is not here — rift is a brew formula plus a login
# agent (modules/darwin/brews.nix, hosts/darwin/default.nix) and its keymap is
# a declarative symlink (modules/darwin/config/rift.toml). This module owns the
# parts whose *look* is meant to be tuned by eye.
#
# ── Installation is declarative, ricing is not ────────────────────────────
# Same split the niri module makes on the NixOS side (modules/nixos/niri):
# nix installs the services and starts them, but the files they read live as
# ordinary writable files in $HOME, seeded from ./sketchybar and ./wezterm only
# when missing. A bar is built by nudging a padding value and looking at it;
# behind a store symlink every nudge costs a rebuild, and sketchybar's own
# `--reload` would be reloading a read-only file it cannot have written.
#
# So ./sketchybar here is a starting point, not the live config. Once seeded,
# ~/.config/sketchybar is the original. There is no rice-save for it yet — copy
# it back by hand if a look is worth keeping.
#
# ── Where the colours come from ───────────────────────────────────────────
# pywal (`wal`) reads a wallpaper and writes a 16-colour palette to
# ~/.cache/wal/. Nothing here hardcodes a scheme; each consumer reads that
# cache and falls back to a built-in palette when it is absent (a fresh machine
# has never run `wal`):
#
#   sketchybar   ~/.config/sketchybar/colors.sh sources ~/.cache/wal/colors.sh
#   jankyborders apps/rice-colors pushes new args into the running instance
#   wezterm      ~/.config/wezterm/wezterm.lua parses ~/.cache/wal/colors.json
#
# `apps/rice-colors <image>` runs wal and then pokes all three. Ghostty is
# deliberately not in that list: its palette is owned by the other ricing axis
# (modules/shared/ghostty.nix + apps/rice-term), and having two generators
# write the same theme file is how you get a look that flips back on the next
# switch.

{
  # ── Status bar ───────────────────────────────────────────────────────────
  # `config` is left at its default (empty) on purpose. Setting it would make
  # nix-darwin pass `--config <store path>`, pinning sketchybarrc to the store
  # — the exact read-only outcome the header above is avoiding. Empty means
  # sketchybar falls back to its own default lookup, ~/.config/sketchybar/
  # sketchybarrc, which is what the activation script below seeds.
  services.sketchybar = {
    enable = true;

    # The LaunchAgent's PATH is built from this list plus environment.systemPath
    # — it inherits nothing from a login shell. Every binary a plugin shells out
    # to has to be reachable one of those two ways.
    #
    # jq: the plugins parse `sketchybar --query` output and pmset/system_profiler
    # JSON. The rest of the plugins' tools (pmset, osascript, sw_vers) are macOS
    # built-ins under /usr/bin, which systemPath already carries.
    extraPackages = with pkgs; [ jq ];
  };

  # ── Window borders ───────────────────────────────────────────────────────
  # NOT `services.jankyborders`, deliberately. That module gives borders its own
  # LaunchAgent, and a LaunchAgent is its own responsible process as far as
  # macOS TCC is concerned — so `ax_focus=on` (the accurate focus mode that
  # glow() needs) would require a separate Accessibility grant and still could
  # not see the focus rift drives through SkyLight.
  #
  # Instead rift spawns borders itself, from ~/.config/borders/bordersrc, and
  # the child inherits rift's trust. See the run_on_start block in
  # modules/darwin/config/rift.toml for the whole reasoning, and ./borders for
  # the seeded script.
  #
  # The package still has to be installed for that script to find `borders`.
  # It goes in environment.systemPackages rather than the user's home.packages
  # because rift's LaunchAgent PATH reaches /run/current-system/sw/bin but NOT
  # ~/.nix-profile/bin — nix-darwin writes that entry as a literal `$HOME/...`
  # which launchd never expands.
  environment.systemPackages = with pkgs; [ jankyborders ];

  # ── Wallpaper → palette, automatically ───────────────────────────────────
  # Without this, `apps/rice-colors` has to be run by hand every time the
  # wallpaper changes. macOS records the current desktop picture in
  #
  #   ~/Library/Application Support/com.apple.wallpaper/Store/Index.plist
  #
  # and rewrites it no matter *how* the wallpaper was changed — System Settings,
  # a picker app, a script. Watching that one file therefore catches every route
  # at once, which is why this is a watcher and not a wrapper around some
  # particular "set wallpaper" command.
  #
  # The plist is only the trigger; the path is read back with osascript, the
  # same way rice-colors does when called with no argument. Parsing the plist
  # ourselves would mean percent-decoding a file:// URL out of XML for a value
  # the OS will hand over on request.
  #
  # NOTE: the first run will raise a macOS Automation prompt (System Events),
  # because a LaunchAgent asking osascript about the desktop is a scripting
  # request. Denying it leaves the watcher running and silently doing nothing.
  launchd.user.agents.wal-watch = {
    command = "${walWatch}";
    path = [
      pkgs.fswatch
      pkgs.pywal16
      pkgs.jankyborders
      config.services.sketchybar.package
      pkgs.coreutils
      config.environment.systemPath
    ];
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = true;
      # Unlike the other agents here, this one is worth being able to read:
      # it is the only piece that runs unattended, so a failure has no visible
      # symptom other than colours quietly not following the wallpaper.
      StandardOutPath = "/tmp/wal-watch.log";
      StandardErrorPath = "/tmp/wal-watch.log";
    };
  };

  home-manager.users.${user} = { lib, ... }: {
    home.packages = with pkgs; [
      # pywal16 rather than pywal: same `wal` command and the same
      # ~/.cache/wal/ layout, but the maintained fork — it emits all 16 colours
      # (upstream pywal only really varies 8) which is what the sketchybar
      # palette and wezterm's brights below actually consume.
      #
      # The nixpkgs wrapper already puts imagemagick on its PATH, so the
      # default backend works with nothing else installed.
      pywal16
    ];

    # Seed the ricing files on a machine that has none yet. Deliberately not
    # home.file / xdg.configFile: those symlink the store and make the target
    # read-only. `seed` copies only when the destination is missing, so a
    # rebuild mid-ricing never clobbers unsaved work — see the helper's header.
    home.activation.seedMacRice = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${import ../../shared/rice-seed-helpers.nix}

      # sketchybarrc + colors.sh + plugins/, as one tree. sketchybar re-execs
      # plugins on every update, so they must stay executable — `seed` chmods
      # u+w but the store copy's +x survives the cp.
      seed ${./sketchybar} "$HOME/.config/sketchybar"

      # wezterm. Secondary terminal (ghostty is the daily one), here mostly
      # because it can read pywal's JSON directly and reload itself.
      seed ${./wezterm} "$HOME/.config/wezterm"

      # 창 테두리. rift 가 run_on_start 에서 이 파일을 실행하고, 팔레트가 바뀔
      # 때마다 apps/rice-colors 가 다시 쓴다.
      seed ${./borders} "$HOME/.config/borders"

      # rift 키바인딩이 부르는 헬퍼들. ~/.config/rift 가 아니라 여기 두는 이유:
      # 그쪽은 config.toml 이 home-manager 심링크로 들어가 있어서 seed 의 디렉터리
      # 존재 검사와 부딪힌다.
      seed ${./bin} "$HOME/.config/rice/bin"

      # WorkspacePeek(Option+Ctrl+W) 설정. 앱 자체는 nix 가 안 깐다 — Swift 로
      # 빌드하는 .app 이라 명령형으로 두었다. 자세한 건 ./peek/README.md.
      #
      # 설정만 여기서 관리하는 게 가능한 이유는 앱이 loadOrCreate 로 *없을 때만*
      # 쓰기 때문이다. 파일이 이미 있으면 앱은 읽기만 하므로, 여기 심어 둔 값이
      # 앱의 기본값에 덮이지 않는다.
      seed ${./workspacepeek/config.json} "$HOME/.config/workspacepeek/config.json"

      # ── 시드한 설정을 실제로 읽히기 ────────────────────────────────────
      # 이 순서 때문에 필요하다: 한 번의 switch 안에서 시스템 활성화가 먼저
      # 돌아 sketchybar LaunchAgent 를 띄우고, home-manager 활성화(위의 seed)는
      # 그 몇 분 뒤에 돈다. 그래서 새 머신의 첫 switch 에서 sketchybar 는
      # ~/.config/sketchybar 가 아직 없는 상태로 뜬다.
      #
      # 그리고 그건 `sketchybar --reload` 로 안 고쳐진다. 시작할 때 설정 파일을
      # 못 찾은 sketchybar 는 다시 읽을 경로를 갖고 있지 않아서, --reload 가
      # 성공하면서 아무것도 안 바뀐다 — 바는 기본값(height 25, 아이템 0개)으로
      # 남고 에러는 어디에도 안 뜬다. 실제로 한 번 겪었다.
      #
      # 그래서 리로드가 아니라 재시작이다. 바가 다시 뜨는 데 드는 비용은
      # 눈에 안 띄는 수준이고, switch 마다 홈 쪽 설정이 확실히 반영된다.
      #
      # rift 는 일부러 여기 없다. 재시작하면 열려 있는 창이 전부 다시 타일링돼서
      # 작업 중이면 방해가 크고, rift 는 hot_reload 로 설정 파일을 스스로
      # 지켜본다. 리빌드가 안 먹은 것 같으면 Alt+Ctrl+R.
      $DRY_RUN_CMD /bin/launchctl kickstart -k \
        "gui/$(/usr/bin/id -u)/org.nixos.sketchybar" 2>/dev/null || true
    '';
  };
}
