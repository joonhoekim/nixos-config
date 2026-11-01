# Caps Lock 레이어(../shared/kanata/kanata.kbd, Windows 와 같은 파일)를 macOS 에서 돌리는 배선. 전체 그림: docs/macos-internals.md
# 드라이버는 pkgs.kanata.passthru.darwinDriver 판이어야 한다 — pqrs 는 마이너 판 사이에도 IPC 를 바꾼다(kanata docs/setup-macos.md).
# 바이너리는 apps/kanata 가 다시 서명한 사본이다: 스토어의 임의 서명(cdhash)이면 판마다 TCC 허가가 조용히 끊긴다.
{ pkgs, ... }:

let
  kanata = pkgs.kanata;
  driver = kanata.passthru.darwinDriver;
  managerApp = "/Applications/.Karabiner-VirtualHIDDevice-Manager.app";
  manager = "${managerApp}/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager";
  vhidDaemon = "${driver}/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon";
  dir = "/usr/local/libexec/kanata";
  bin = "${dir}/kanata";
in
{
  # apps/kanata 가 서명할 원본을 /run/current-system 을 뒤지지 않고 이름 하나로 집는 자리.
  environment.etc."kanata/kanata-unsigned".source = "${kanata}/bin/kanata";
  environment.etc."kanata/kanata.kbd".source = "${../shared/kanata/kanata.kbd}";

  # 판이 바뀔 때만 갈아 넣는다 — 주인 앱을 매번 지웠다 두면 macOS 가 확장을 비활성화하는 일이 있다.
  # preActivation 이어야 아래 데몬이 올라오기 전에 앱이 제자리에 있다.
  system.activationScripts.preActivation.text = ''
    want=${driver.version}
    have=$(/usr/bin/defaults read "${managerApp}/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || true)
    if [ "$have" != "$want" ]; then
      echo "installing Karabiner VirtualHIDDevice Manager $want (was: ''${have:-none})..." >&2
      rm -rf "${managerApp}"
      cp -R "${driver}/Applications/.Karabiner-VirtualHIDDevice-Manager.app" "${managerApp}"
    fi
  '';

  launchd.daemons = {
    # activate 는 처음이면 시스템 설정의 승인을 기다리므로 build-switch 가 아니라 여기서 부른다.
    # 이 데몬이 없으면 kanata 는 `connect_failed asio.system:2` 만 반복하고 키는 조용히 그대로 나간다.
    karabiner-vhid-daemon = {
      script = ''
        "${manager}" activate
        exec "${vhidDaemon}"
      '';
      serviceConfig = {
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Interactive";
        StandardOutPath = "/var/log/karabiner-vhid-daemon.log";
        StandardErrorPath = "/var/log/karabiner-vhid-daemon.log";
      };
    };

    # 셸을 거치면 TCC 가 허가를 찾는 대상이 그 셸이 될 수 있어 직접 띄운다. wait4path 래퍼도 안 거치니
    # 바이너리와 설정이 /nix 를 가리키면 안 된다. kanata.kbd 를 바꾼 뒤 교체·재시작은 apps/kanata --auto 가 한다.
    kanata = {
      serviceConfig = {
        ProgramArguments = [ bin "--cfg" "${dir}/kanata.kbd" ];
        RunAtLoad = true;
        # 그냥 KeepAlive 면 apps/kanata 를 아직 안 돌린 기계에서 재시작 루프가 된다.
        KeepAlive.PathState.${bin} = true;
        ProcessType = "Interactive";
        StandardOutPath = "/var/log/kanata.log";
        StandardErrorPath = "/var/log/kanata.log";
      };
    };
  };
}
