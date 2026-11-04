{ ... }:

# 로그인 상태는 기계마다 /var/lib/tailscale 에만 있다. 공개 저장소라 auth key 를 식에 넣지 않고
# 기계마다 한 번 `sudo tailscale up` 한다. 쓰는 법: docs/tailscale.md
{
  services.tailscale = {
    enable = true;
    # 41641/udp. 닫혀 있으면 기계끼리 직접 붙지 못하고 DERP 릴레이로만 오가며, 오류 없이 느려지기만 한다.
    openFirewall = true;
    # exit node 를 쓸 때 필요한 rp_filter=loose. 없으면 exit node 를 켜는 순간 응답 패킷이 버려져 인터넷이 끊긴다.
    useRoutingFeatures = "client";
  };
}
