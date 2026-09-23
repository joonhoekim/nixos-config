{ ... }:

# 부팅 때 wg0 을 올린다. 설정과 개인키는 기계마다 손으로 둔
# /etc/wireguard/wg0.conf 에만 있고, 이 파일은 그 경로를 가리키기만 한다 —
# 공개 저장소라 키를 nix 식에 넣으면 /nix/store 와 GitHub 양쪽에 남는다.
# 쓰는 법은 docs/wireguard.md.
#
# configFile 이 문자열 경로라서 스토어로 복사되지 않는다. nixpkgs 의
# nixos/modules/services/networking/wg-quick.nix 는 유닛이 뜰 때마다 이 파일을
# PrivateTmp 로 cp 한 뒤 `wg-quick up` 하므로, 파일을 고친 다음에는
# `systemctl restart wg-quick-wg0` 만 하면 되고 rebuild 는 필요 없다.
let conf = "/etc/wireguard/wg0.conf"; in
{
  networking.wg-quick.interfaces.wg0.configFile = conf;

  # 파일이 없는 호스트(아직 터널을 안 받은 기계)에서는 유닛을 건너뛴다. 이 줄이
  # 없으면 그 기계는 부팅과 switch 때마다 wg-quick-wg0 이 failed 로 찍히고,
  # switch 가 0 이 아닌 코드로 끝난다.
  systemd.services.wg-quick-wg0.unitConfig.ConditionPathExists = conf;
}
