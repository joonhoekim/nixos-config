{ ... }:

# 설정과 개인키는 기계마다 손으로 둔 /etc/wireguard/wg0.conf 에만 있다(공개 저장소). 쓰는 법: docs/wireguard.md
# 문자열 경로라 스토어로 복사되지 않아, 고친 뒤 `systemctl restart wg-quick-wg0` 이면 된다(rebuild 불필요).
# `systemctl restart wg-quick-wg0` 만 하면 되고 rebuild 는 필요 없다.
let conf = "/etc/wireguard/wg0.conf"; in
{
  networking.wg-quick.interfaces.wg0.configFile = conf;

  # 없으면 파일이 없는 기계에서 부팅·switch 마다 failed 가 찍히고 switch 가 0 이 아닌 코드로 끝난다.
  systemd.services.wg-quick-wg0.unitConfig.ConditionPathExists = conf;
}
