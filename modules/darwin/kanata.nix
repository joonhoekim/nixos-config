# Caps Lock 레이어를 kanata 로 건다. 레이어 자체는 ../shared/kanata/kanata.kbd
# 이고 Windows 와 같은 파일이다. 여기는 macOS 에서 그걸 돌리는 배선만 있다.
#
# kanata 는 키보드를 Karabiner-DriverKit-VirtualHIDDevice 로 잡고, 그 드라이버의
# 유저 공간 데몬과 소켓으로 말한다. 그래서 세 조각이 필요하다:
#
#   1. 확장(dext)을 품은 Manager 앱 — /Applications 안에 실제 파일로 있어야 한다.
#      시스템 확장은 심링크나 /nix/store 에서 활성화되지 않는다.
#   2. VirtualHIDDevice-Daemon — root 로 돈다. 소켓이
#      /Library/Application Support/org.pqrs/tmp/rootonly/ 에 생기고, 그래서
#      kanata 도 root 여야 한다.
#   3. kanata — root 데몬. 바이너리와 설정은 스토어가 아니라 /usr/local/libexec/kanata/ 에
#      있다.
#
# 드라이버 버전은 pkgs.kanata.passthru.darwinDriver 를 그대로 쓴다. kanata 의
# karabiner-driverkit 크레이트가 그 릴리스의 IPC 에 맞춰 빌드되고, pqrs 는 마이너
# 버전 사이에도 프로토콜을 바꾼다(kanata docs/setup-macos.md). Karabiner-Elements 를
# 같이 깔면 안 되는 이유가 이것이다 — KE 16.3 이 까는 데몬은 8.5.0 이고, kanata
# 1.12 가 아는 것은 6.2.0 이다. 둘 다 키보드를 독점으로 잡으려 하는 것도 있다.
#
# 3 이 스토어 경로가 아닌 이유: 입력 모니터링·손쉬운 사용 허가는 TCC 가 바이너리의
# 서명 요구사항에 묶는다. nix 가 빌드한 바이너리는 임의 서명이라 요구사항이
# cdhash 이고, kanata 판이 바뀔 때마다 허가가 **조용히** 끊긴다 — 설정 화면의
# 체크박스는 켜진 채로 레이어만 안 먹는다(apps/mac-signing-cert 머리말). 그래서
# apps/kanata 가 스토어의 바이너리를 이 기계 신원으로 다시 서명해서 그 자리에 둔다.
# 설정도 같이 복사해서, 부팅 때 /nix 가 붙기 전에 떠도 /nix 를 건드릴 일이 없다
# (apps/kanata 머리말). build-switch 가 매번 부른다.
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
  # apps/kanata 가 서명할 원본을 찾는 자리. /run/current-system 을 뒤지지 않고
  # 이름 하나로 집게 한다.
  environment.etc."kanata/kanata-unsigned".source = "${kanata}/bin/kanata";
  environment.etc."kanata/kanata.kbd".source = "${../shared/kanata/kanata.kbd}";

  # Manager 앱은 판이 바뀔 때만 갈아 넣는다. 활성화된 확장의 주인 앱을 매번
  # 지웠다 다시 두면, 그 사이에 macOS 가 확장을 주인 없는 것으로 보고 비활성화를
  # 거는 일이 있다(같은 판을 다시 activate 하는 것 자체는 아무 일도 안 한다).
  # preActivation 인 것은 아래 데몬이 올라오기 전에 앱이 제자리에 있어야 해서다.
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
    # activate 는 확장이 이미 같은 판으로 켜져 있으면 바로 끝나고, 처음이면
    # 시스템 설정의 승인을 기다린다. 그래서 build-switch 가 아니라 여기서 부른다 —
    # 승인 창 앞에서 활성화가 멈춰 서지 않게.
    #
    # 이 데몬이 없으면 kanata 는 떠 있는 채로 `connect_failed asio.system:2` 를
    # 로그에 반복하고, 키는 kanata 를 거치지 않은 그대로 나간다.
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

    # ProgramArguments 로 바이너리를 직접 띄운다. 셸을 거치면 TCC 가 허가를
    # 찾는 대상이 그 셸이 될 수 있다. 같은 이유로 launchd-names.nix 의
    # wait4path 래퍼도 안 거치므로, 바이너리와 설정이 /nix 를 가리키면 안 된다.
    #
    # 설정은 고정 경로라 kanata.kbd 가 바뀌어도 plist 는 그대로다. 복사본을
    # 갈아 넣고 데몬을 다시 띄우는 것은 apps/kanata --auto 가 한다.
    kanata = {
      serviceConfig = {
        ProgramArguments = [ bin "--cfg" "${dir}/kanata.kbd" ];
        RunAtLoad = true;
        # 바이너리가 있는 동안만 살려 둔다. apps/kanata 를 아직 안 돌린
        # 기계에서는 띄울 것이 없고, 그냥 KeepAlive 면 재시작 루프가 된다.
        KeepAlive.PathState.${bin} = true;
        ProcessType = "Interactive";
        StandardOutPath = "/var/log/kanata.log";
        StandardErrorPath = "/var/log/kanata.log";
      };
    };
  };
}
