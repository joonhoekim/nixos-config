{ config, pkgs, user, ... }:

let
  # 벽지가 바뀌면 apps/rice/colors 를 부른다 — 손으로 부를 때와 같은 절차가 돈다.
  wallpaperPath = "${pkgs.python3}/bin/python3 ${../../../apps/rice/wallpaper-path.py}";

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
      ${../../../apps/rice/colors} "$img" || echo "rice-colors 실패"
    }

    # 로그인 직후 한 번. state 검사가 있어 로그인 사이에 벽지가 바뀐 경우만 wal 이 돈다.
    apply

    # 새 계정엔 plist 가 없다. fswatch 는 없는 경로에 바로 죽고 KeepAlive 가 그걸 재시작 루프로 만든다.
    while [ ! -f "$plist" ]; do sleep 30; done

    fswatch -o "$plist" | while read -r _; do
      apply
    done
  '';
in

# 아래 파일은 시드다 — 심은 뒤로는 ~/.config 가 원본이고 apps/rice/save · restore 가 양쪽을 옮긴다.
# 전체 그림: docs/macos-rice.md

{
  # macOS rewrites Index.plist however the wallpaper was changed, so watching that one file catches every route.
  launchd.user.agents.wal-watch = {
    command = "${walWatch}";
    path = [
      pkgs.fswatch
      pkgs.pywal16
      pkgs.coreutils
      config.environment.systemPath
    ];
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = true;
      # The only piece that runs unattended: without a log, a failure shows
      # only as colours quietly not following the wallpaper.
      StandardOutPath = "/tmp/wal-watch.log";
      StandardErrorPath = "/tmp/wal-watch.log";
    };
  };

  home-manager.users.${user} = { lib, ... }: {
    home.packages = with pkgs; [
      # pywal16, not pywal: upstream only really varies 8 of the 16 colours, and wezterm's brights
      # and the border ranking in apps/rice/colors use all 16.
      pywal16
    ];

    # Not home.file / xdg.configFile: those symlink the store and make the
    # target read-only. `rice_sync` only overwrites a file nobody has touched
    # (modules/shared/rice-seed-helpers.nix).
    home.activation.seedMacRice = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${import ../../shared/rice-seed-helpers.nix}

      rice_sync ${./wezterm} "$HOME/.config/wezterm"

      rice_sync ${./rift-grid/config.toml} "$HOME/.config/rift-grid/config.toml"

      # 첫 설치에서 LinearMouse 가 먼저 떠 빈 설정을 만들면 "있음"으로 통과해 휠 방향만 조용히 안 바뀐다.
      # 그래서 schemes 가 빈 파일은 없는 것으로 친다. JSON 이 깨져 있으면(고치던 중) 손대지 않는다.
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
      rice_sync ${./linearmouse/linearmouse.json} "$lmcfg"

      # rift-grid 키바인딩이 부르는 헬퍼. rift-grid/config.toml 이 이 경로를 직접 쓰므로
      # 옮기려면 키맵도 같이 고친다.
      rice_sync ${./bin} "$HOME/.config/rice/bin"

      # reload 단계는 없다 — 각 앱이 제 설정 파일을 감시하고 rice/bin 은 부를 때마다 읽힌다.
      # apps/rice/restore 는 rm+cp 로 감시를 끊으므로 그쪽이 reload 를 부른다.
    '';
  };
}
