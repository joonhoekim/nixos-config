# Caps 레이어의 포인터 쪽: keyd 가 내는 F키 센티넬을 포인터 이동·휠·버튼으로 바꾸는 데몬.
# keyd 는 포인터를 못 움직인다. 전체 그림: modules/nixos/README.md 「포인터 (pointer)」
{ pkgs, ... }:

let
  python = pkgs.python3.withPackages (ps: [ ps.evdev ]);
in
{
  systemd.services.pointerd = {
    description = "Pointer motion for the Caps Lock layer";

    # `after` 는 첫 시작 순서뿐이다. 데몬이 장치를 기다리고 keyd 재시작 때 다시 붙는다.
    after = [ "keyd.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      # root: /dev/input 을 읽고 uinput 장치를 만든다(uinput 은 hosts/nixos/common.nix 가 로드).
      ExecStart = "${python}/bin/python3 ${./pointerd.py}";
      Restart = "always";
      RestartSec = 2;
      # 초당 125 번 미는 포인터가 다른 것을 버벅이게 하면 안 된다.
      Nice = -5;
    };
  };
}
