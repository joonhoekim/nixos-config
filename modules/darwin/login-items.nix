{ config, lib, user, ... }:

let
  # 앱이 없는데 `open -a` 를 남기면 로그인마다 실패하고 apps/check/mac 이 그 job 을 ✗ 로 보인다.
  hasCask = name: builtins.elem name (map (c: c.name) config.homebrew.casks);
in

{
  # Apps' own start-at-login toggles don't stick on recent macOS, so login items are per-user LaunchAgents.
  launchd.user.agents = {
    # rift-grid is built and signed per machine by apps/rift-grid, not nix or brew: TCC ties its grants to the
    # signature (reasoning at the top of apps/rift-grid). `path`: its keybindings shell out to rift-grid-cli and
    # systemPath tools, and a LaunchAgent inherits none of a login shell's PATH.
    rift-grid = {
      command = "/Users/${user}/.local/bin/rift-grid";
      path = [ "/Users/${user}/.local/bin" config.environment.systemPath ];
      # Unset, tracing's EnvFilter keeps only errors: an app it gave up attaching to leaves no line in the log.
      environment.RUST_LOG = "warn";
      serviceConfig = {
        RunAtLoad = true;
        # Plain KeepAlive would restart-loop until apps/rift-grid builds the binary; PathState waits for it.
        KeepAlive.PathState."/Users/${user}/.local/bin/rift-grid" = true;
        # Without these, refusal reasons and run_on_start failures go to an unread stdout — the WM just silently doesn't run.
        StandardOutPath = "/tmp/rift-grid.log";
        StandardErrorPath = "/tmp/rift-grid.log";
      };
    };
    # Driven from launchd, not Stats' own SMAppService login item that the app rewrites from its prefs.
    # `open -a` as with linearmouse below: if that in-app toggle is ever on, a direct exec gives two Stats
    # (`sudo sfltool dumpbtm` prints both dispositions). 전체 그림: docs/macos-internals.md
    stats = lib.mkIf (hasCask "stats") {
      command = "/usr/bin/open -a /Applications/Stats.app";
      serviceConfig.RunAtLoad = true;
    };

    # 외장 마우스 휠만 뒤집는다(설정과 근거: modules/darwin/rice/linearmouse/README.md).
    # Mach-O 직접 exec 이 아니라 `open -a` 여야 앱 자체 로그인 항목과 겹쳐도 하나만 뜬다. 둘이 뜨면 서로
    # 상쇄해 "아이콘 둘 + 휠 방향 그대로"로 보인다. 전체 그림: docs/macos-internals.md
    linearmouse = lib.mkIf (hasCask "linearmouse") {
      command = "/usr/bin/open -a /Applications/LinearMouse.app";
      serviceConfig.RunAtLoad = true;
    };
  };
}
