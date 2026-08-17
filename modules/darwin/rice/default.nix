{ config, pkgs, user, ... }:

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

# macOS ricing: the window borders and the colour generator that feeds them.
#
# The window manager itself is not here — rift is a brew formula plus a login
# agent (modules/darwin/brews.nix, hosts/darwin/default.nix). Its keymap IS
# here as of 2026-08-06 (./rift/config.toml, seeded like everything else in
# this module); before that it was a read-only store symlink, which broke the
# moment rift's own "settings" item started opening it in an editor.
#
# ── There is no status bar here, and that was a decision ──────────────────
# sketchybar lived in this module until 2026-08-05. It drew six things and five
# of them were already in the macOS menu bar — clock, battery, CPU (stats), input
# source, focused app. The one that was not, the rift workspace indicator, now
# comes from rift itself (`[settings.ui.menu_bar]` in
# modules/darwin/rice/rift/config.toml): no extra process, no Screen Recording
# grant, nothing to re-approve when a nixpkgs bump changes a hash.
#
# Replacing the whole menu bar was the alternative, and it does not work.
# Aliasing the real menu extras into sketchybar renders them — verified — but
# it only mirrors their *picture*; clicking one needs an accessibility helper,
# and the app menus on the left cannot be aliased at all. Two TCC grants on
# ad-hoc-signed store binaries, to reproduce what macOS gives for free.
#
# So: macOS keeps its menu bar. `git log -- modules/darwin/rice/sketchybar`
# has the config if it ever earns its place back.
#
# ── Installation is declarative, ricing is not ────────────────────────────
# Same split the niri module makes on the NixOS side (modules/nixos/niri):
# nix installs the services and starts them, but the files they read live as
# ordinary writable files in $HOME, seeded from the directories below only when
# missing. A border width or a gap is settled by nudging it and looking; behind
# a store symlink every nudge costs a rebuild.
#
# So the trees here are starting points, not the live config. Once seeded,
# ~/.config is the original — `apps/rice-save` carries changes back to the repo
# and `apps/rice-restore` pushes the repo the other way.
#
# ── Where the colours come from ───────────────────────────────────────────
# pywal (`wal`) reads a wallpaper and writes a 16-colour palette to
# ~/.cache/wal/. Nothing here hardcodes a scheme; each consumer reads that
# cache and falls back to a built-in palette when it is absent (a fresh machine
# has never run `wal`):
#
#   jankyborders  apps/rice-colors pushes new args into the running instance
#   wezterm       ~/.config/wezterm/wezterm.lua parses ~/.cache/wal/colors.json
#   WorkspacePeek reads ~/.cache/wal/colors.json itself (useWalColors)
#
# `apps/rice-colors <image>` runs wal and then pokes them. Ghostty is
# deliberately not in that list: its palette is owned by the other ricing axis
# (modules/shared/ghostty + apps/rice-term), and having two generators
# write the same theme file is how you get a look that flips back on the next
# switch.

{
  # ── Window borders ───────────────────────────────────────────────────────
  # NOT `services.jankyborders`, deliberately. That module gives borders its own
  # LaunchAgent, and a LaunchAgent is its own responsible process as far as
  # macOS TCC is concerned — so `ax_focus=on` (the accurate focus mode that
  # glow() needs) would require a separate Accessibility grant and still could
  # not see the focus rift drives through SkyLight.
  #
  # Instead rift spawns borders itself, from ~/.config/borders/bordersrc, and
  # the child inherits rift's trust. See the run_on_start block in
  # modules/darwin/rice/rift/config.toml for the whole reasoning, and ./borders for
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
      # (upstream pywal only really varies 8) which is what wezterm's brights
      # and the border luminance ranking in apps/rice-colors consume.
      #
      # The nixpkgs wrapper already puts imagemagick on its PATH, so the
      # default backend works with nothing else installed.
      pywal16
    ];

    # Seed the ricing files on a machine that has none yet. Deliberately not
    # home.file / xdg.configFile: those symlink the store and make the target
    # read-only. `seed` copies only when the destination is missing, so a
    # rebuild mid-ricing never clobbers unsaved work — see the helper's header.
    # linkGeneration 뒤에 두는 건 아래 unstore 때문이다. 이전 세대의 심링크를
    # 걷어내는 건 home-manager 도 하는데, 그게 seed 보다 나중에 돌면 방금 심은
    # 진짜 파일을 보고 판단하게 된다. 순서를 못 박아 두면 그 경우가 아예 없다.
    home.activation.seedMacRice = lib.hm.dag.entryAfter [ "writeBoundary" "linkGeneration" ] ''
      ${import ../../shared/rice-seed-helpers.nix}

      # ── 심링크에서 시드로 넘어오는 한 번을 위한 것 ──────────────────────
      # 아래 셋(karabiner.json, aerospace.toml, rift 의 config.toml)은
      # 2026-08-06 까지 modules/darwin/files.nix 가 거는 읽기 전용 스토어
      # 심링크였다. seed 의 존재 검사는 링크도 "있음"으로 보므로, 걷어내지
      # 않으면 그 머신들에는 영영 안 심긴다.
      #
      # 스토어를 가리키는 링크일 때만 지운다. 평범한 파일이면 이미 손댄
      # 설정이고, 스토어 밖을 가리키는 링크라면 일부러 그렇게 둔 것이다 —
      # 둘 다 건드리면 안 된다.
      unstore() { # unstore <path>
        case "$(readlink "$1" 2>/dev/null)" in
          /nix/store/*) $DRY_RUN_CMD rm -f "$1"; echo "unlinked store symlink $1" ;;
        esac
      }

      # wezterm. Secondary terminal (ghostty is the daily one), here mostly
      # because it can read pywal's JSON directly and reload itself.
      seed ${./wezterm} "$HOME/.config/wezterm"

      # 창 테두리. rift 가 run_on_start 에서 이 파일을 실행하고, 팔레트가 바뀔
      # 때마다 apps/rice-colors 가 다시 쓴다.
      seed ${./borders} "$HOME/.config/borders"

      # rift 의 키맵. rift 의 "settings" 메뉴가 이 파일을 에디터로 여는데 스토어
      # 심링크는 읽기 전용이라 저장이 안 되는 자리였다.
      unstore "$HOME/.config/rift/config.toml"
      seed ${./rift/config.toml} "$HOME/.config/rift/config.toml"

      # Karabiner 의 키맵. 여기 셋 중 심링크가 제일 안 맞던 자리다 — 설정 GUI 가
      # 저장할 때마다 조용히 실패했고, ./karabiner/README.md 에는 그걸 우회하는
      # 절차("심링크 지우고 → 복사본 두고 → 다 되면 되돌리고 build-switch")가
      # 아예 문서로 적혀 있었다. 그 우회가 지금은 그냥 기본 동작이다.
      #
      # 디렉터리가 아니라 파일 하나만 심는 이유: ~/.config/karabiner 에는 앱이
      # 만드는 assets/ 와 automatic_backups/ 가 같이 산다. 통째로 다루면 그것까지
      # 레포가 관리하게 된다.
      unstore "$HOME/.config/karabiner/karabiner.json"
      seed ${./karabiner/karabiner.json} "$HOME/.config/karabiner/karabiner.json"

      # 마우스 휠 방향(트랙패드는 건드리지 않는다). ./linearmouse/README.md.
      #
      # 시드의 존재 검사가 여기서만 한 번 새는 자리가 있다: LinearMouse 는 처음 뜰 때
      # 설정이 없으면 **빈 설정을 스스로 만든다.** 그리고 이 활성화보다 앱이 먼저 뜨는
      # 경우가 실제로 있다 — launchd 에이전트를 거는 것도 같은 build-switch 안이라 첫
      # 설치에서 순서가 어느 쪽으로든 갈 수 있다. 그러면 앱이 만든 빈 파일이 존재 검사를
      # 통과해서, 리빌드는 성공했는데 휠 방향만 안 바뀌는 상태로 끝난다.
      #
      # 그래서 규칙이 하나도 없는 파일은 "없는 것"으로 친다. 손으로 쓴 설정은 schemes 가
      # 비어 있지 않으니 안 걸리고, JSON 이 깨져 있으면(= 고치던 중이다) 손대지 않는다.
      lmcfg="$HOME/.config/linearmouse/linearmouse.json"
      if [ -f "$lmcfg" ] && ${pkgs.python3}/bin/python3 -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
sys.exit(0 if not d.get("schemes") else 1)
' "$lmcfg"; then
        $DRY_RUN_CMD rm -f "$lmcfg"
        echo "removed empty linearmouse.json (앱이 만든 빈 설정)"
      fi
      seed ${./linearmouse/linearmouse.json} "$lmcfg"

      # AeroSpace 의 설정. rift 로 옮겨 간 뒤로 로그인에 뜨지 않지만 `open -a
      # AeroSpace` 폴백은 그대로라 설정도 유효하다. rift 가 완전히 자리 잡으면
      # 이 줄과 ./aerospace 를 casks.nix 의 항목과 함께 지우면 된다.
      unstore "$HOME/.config/aerospace/aerospace.toml"
      seed ${./aerospace/aerospace.toml} "$HOME/.config/aerospace/aerospace.toml"

      # rift 키바인딩이 부르는 헬퍼들. ~/.config/rift 가 아니라 여기 두는 이유는
      # 원래 위 심링크와 부딪혀서였는데 그 제약은 사라졌다. 그래도 그대로 두는
      # 건 rift/config.toml 이 이 경로를 박아서 부르기 때문이다 — 옮기려면 키맵과
      # 같이 옮겨야 하고, 그건 이 변경과 별개다.
      seed ${./bin} "$HOME/.config/rice/bin"

      # WorkspacePeek(Option+Ctrl+W) 설정. 앱 자체는 nix 가 안 깐다 — Swift 로
      # 빌드하는 .app 이라 명령형으로 두었다. 자세한 건 ./workspacepeek/README.md.
      #
      # 설정만 여기서 관리하는 게 가능한 이유는 앱이 loadOrCreate 로 *없을 때만*
      # 쓰기 때문이다. 파일이 이미 있으면 앱은 읽기만 하므로, 여기 심어 둔 값이
      # 앱의 기본값에 덮이지 않는다.
      seed ${./workspacepeek/config.json} "$HOME/.config/workspacepeek/config.json"

      # 시드한 것을 다시 읽히는 단계는 여기 없다 — 일곱 다 그럴 필요가 없기
      # 때문이다. wezterm 과 Karabiner 는 자기 설정 파일을 지켜보고, bordersrc 와
      # rice/bin 은 다음 호출부터 새 내용으로 실행되는 셸 스크립트이며,
      # WorkspacePeek·rift·AeroSpace 는 애초에 파일이 없을 때만 시드가
      # 일어난다(= 아직 아무도 안 읽었다).
      #
      # 심링크에서 넘어오는 그 한 번만 예외인데, 그때도 감시자가 새로 생긴 파일을
      # 집어 간다. rift 가 안 먹은 것 같으면 Alt+Ctrl+R, Karabiner 는 설정 앱에서
      # 프로파일을 다시 고르면 된다.
      #
      # 레포에서 라이브로 밀어 넣는 방향은 얘기가 다르다 — apps/rice-restore 는
      # rm+cp 로 덮어서 감시가 걸려 있던 아이노드를 날리므로, 그쪽은 복원 뒤에
      # 명시적으로 reload 를 부른다.
    '';
  };
}
