{ pkgs, ... }:

# 세션(subline) 밖의 데스크톱 기반. 데스크톱 환경 모듈을 켜지 않으므로 그런 모듈이 mkDefault 로
# 켜 주는 것들을 여기서 직접 켠다. 한 줄을 빼면 빌드는 통과하고 해당 기능만 조용히 사라진다.
{
  # 비밀 저장소(org.freedesktop.secrets). subline 포털 설정이 Secret 을 여기로 보내고(subline nix/module.nix),
  # Chrome·VS Code 가 여기에 암호를 둔다. 없으면 그 앱들이 평문 저장으로 조용히 넘어간다.
  # 로그인 때 풀리는 것은 greetd 의 PAM 이 login 스택을 끌어 쓰기 때문이다(docs/nixos-common.md).
  # services.gnome.gcr-ssh-agent 의 기본값이 이 값이라 SSH_AUTH_SOCK 의 에이전트도 이 줄에서 온다.
  services.gnome.gnome-keyring.enable = true;

  # subline 설정의 블루투스(org.bluez)·배터리(org.freedesktop.UPower)가 읽는 데몬.
  hardware.bluetooth.enable = true;
  services.upower.enable = true;

  # 외장 디스크 마운트. Thunar 의 gvfs·thunar-volman 이 이 데몬에 묻는다(./thunar.nix).
  services.udisks2.enable = true;

  # CUPS 가 네트워크 프린터를 찾는 mDNS. 프린터 추가·삭제 GUI 는 system-config-printer.
  services.avahi.enable = true;
  programs.system-config-printer.enable = true;

  # 접근성 버스. 없으면 GTK 앱마다 "Couldn't connect to accessibility bus" 를 찍고 시작이 늦어진다.
  services.gnome.at-spi2-core.enable = true;

  # Thunderbolt·USB4 장치 승인(boltd). 없으면 보안 수준이 user 인 포트에 꽂은 독의 PCIe 터널이
  # 승인되지 않아, 독의 USB 는 되는데 그 뒤의 NVMe·eGPU 만 안 보인다.
  services.hardware.bolt.enable = true;

  # 외장 모니터 DDC/CI(apps/ddc-probe 의 ddcutil)가 /dev/i2c-* 를 여는 권한.
  hardware.i2c.enable = true;

  # libadwaita 앱의 UI 글꼴(Adwaita Sans). 없으면 fontconfig 폴백으로 바뀌어 줄 간격이 달라진다.
  fonts.packages = [ pkgs.adwaita-fonts ];

  environment.systemPackages = with pkgs; [
    # gsettings·gdbus. subline 이 강조색·다크 모드를 GTK 앱에 gsettings 로 알리고 gdbus 로 포털을 부른다.
    glib
    # ~/Downloads 같은 XDG 폴더를 처음 로그인 때 만든다(/etc/xdg/autostart).
    xdg-user-dirs
    # 알림음이 가리키는 기본 소리 테마.
    sound-theme-freedesktop
  ];

  # 기본값은 share 아래 몇 디렉터리만 시스템 프로필에 잇는다. 통째로 잇지 않으면 패키지가 서로의 자료를
  # /run/current-system/sw/share 에서 찾는 자리가 조용히 빈다: share/Thunar(보내기 메뉴)·share/xfce4(도우미
  # 앱 정의)·share/backgrounds·share/locale 이 빠지는 것을 빌드 결과에서 확인했다.
  environment.pathsToLink = [ "/share" ];

  # gsettings 는 XDG_DATA_DIRS 에서 스키마를 찾는데 NixOS 는 패키지별 디렉터리에 둔다. 이 줄이 없으면
  # `gsettings get org.gnome.desktop.interface …` 가 "No such schema" 로 실패하고, subline 은 그 실패를
  # 디버그 로그로만 남겨 GTK 앱이 강조색·다크 모드를 따라오지 않는다.
  environment.sessionVariables.XDG_DATA_DIRS = [
    "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
  ];
}
