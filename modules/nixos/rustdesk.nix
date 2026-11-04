{ config, lib, pkgs, ... }:

# RustDesk 로 이 기계가 원격 제어를 받는 쪽: root 서비스와 tailnet 직접 접속 포트. 앱 자체는 gui-apps.nix 가 깔고,
# 여기는 그 목록(local.guiApps)에 "rustdesk" 가 있을 때 따라 켜진다. 쓰는 법과 세션별로 되는 것: docs/tailscale.md
let
  # gui-apps.nix 의 rustdesk 와 같은 것. 다르면 앱과 서비스가 띄우는 --server 의 버전이 어긋난다.
  pkg = pkgs.rustdesk-flutter;
in
{
  options.local.rustdesk.enable = lib.mkOption {
    type = lib.types.bool;
    default = lib.elem "rustdesk" config.local.guiApps;
    description = "이 기계를 RustDesk 로 원격에서 제어받게 하는 서비스와 tailnet 포트.";
  };

  config = lib.mkIf config.local.rustdesk.enable {
    # nixpkgs 에는 클라이언트 쪽 모듈이 없다(services.rustdesk-server 는 중계 서버다). 상류 res/rustdesk.service 를 옮긴 것.
    # 이게 떠 있어야 Wayland 에서 입력이 들어간다: 서버 프로세스가 있으면 RustDesk 는 화면을 ScreenCast 포털로 받고
    # 입력은 uinput 으로 넣는다(libs/scrap/src/wayland/pipewire.rs 의 is_server_running). 없으면 RemoteDesktop 포털로
    # 가는데 subline·niri·Hyprland 의 포털에는 그게 없어, 화면은 보이고 마우스·키보드는 조용히 안 먹는다.
    systemd.services.rustdesk = {
      description = "RustDesk service (incoming connections)";
      # wantedBy 가 없어 부팅 때 뜨지 않는다. 받을 때만 앱의 서비스 시작 버튼이나 `sudo systemctl start rustdesk` 로 켠다.
      # 떠 있는 동안 공용 중계 서버에 등록돼 접속을 받고, 메모리를 PSS 로 약 70 MiB 쓴다(mn56, 접속 없을 때).
      # 앱의 버튼은 `systemctl enable` 도 부르는데, [Install] 이 없는 유닛이라 경고만 내고 아무것도 바꾸지 않는다.
      after = [ "systemd-user-sessions.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      # 상류는 명령을 /bin, /usr/bin 에서 찾고 없으면 `which` 로 찾는다(hbb_common/src/platform/linux.rs 의 find_cmd_path).
      # seat0 의 사용자를 loginctl 로 고르고 `sudo -E -u <user>` 로 `--server` 를 그 세션에 띄우며, 떴는지는 `ps aux | grep` 으로 본다.
      path = [ pkgs.which pkgs.procps pkgs.systemd pkgs.gnugrep pkgs.coreutils "/run/wrappers" ];
      serviceConfig = {
        # bin/ 의 래퍼로 띄운다. 래퍼의 GST_PLUGIN_SYSTEM_PATH_1_0 이 `sudo -E` 로 --server 까지 가야 pipewire 캡처가 된다.
        ExecStart = "${pkg}/bin/rustdesk --service";
        Restart = "always";
        RestartSec = 2;
        LimitNOFILE = 100000;
      };
    };

    # 직접 IP 접속(설정 → 보안 → "직접 IP 접속 허용"). tailnet 에만 열어 공용 중계를 거치지 않고 붙는다.
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 21118 ];
  };
}
