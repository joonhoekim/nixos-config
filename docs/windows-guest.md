# Windows 게스트 (libvirt/QEMU-KVM)

`modules/nixos/libvirt.nix` 는 mn56 에 Windows 11 VM 을 돌릴 libvirt(가상 머신 관리 데몬)와 QEMU-KVM 을 깐다. 용도는
업무 앱의 TrustNet 공동인증 흐름 시험이다. GUI 는 virt-manager.

## 왜 VM 인가

업무 앱의 공동인증 흐름 중 서명 쪽은 네이티브 Windows 프로그램이다. 브라우저 SDK 는 스스로 서명하지 않고
localhost:18448(그다음 28448, 38448)에서 설치 프로그램이 두는 로컬 HTTPS 데몬을 찾으며, npkisign.js 는
`navigator.platform.toLowerCase() !== "win32"` 면 non-win32 분기로 간다. 리눅스 쪽 작업으로는 못 닿고, 프로그램이
서비스 + Windows 인증서 저장소 통합이라 Wine 도 안 된다.

이 머신은 반대편을 서빙한다 — nginx 가 재현한 웹앱 앞에 있어([nginx](nginx.md)) NAT 게스트가 완전한 고리를 얻는다:
게스트 브라우저 → 호스트 nginx → TrustNet Tomcat 컨테이너. 업무 노트북이 아니라 VM 인 이유는 스냅숏이다 — 시험하는
경로가 "미설치 → 설치" 전이라 여러 번 걸어야 하고, qcow2 가 설치 전 상태를 돌려준다.

## 펌웨어와 TPM

Windows 11 은 UEFI 와 TPM 2.0 없이 설치를 안 하고, 첫 화면에서 무엇이 빠졌는지 말없이 거부한다.

- 선언할 것은 TPM 뿐이다. virtualisation.libvirtd.qemu.ovmf 는 nixpkgs 에서 빠졌고(QEMU 의 모든 OVMF 이미지가 Secure
  Boot 변형까지 기본 등록된다) 설정하면 빌드 시 assertion 이 난다.
- 펌웨어는 virt-manager 에서 게스트마다 고른다("Customize configuration before install" → Overview → Firmware → UEFI).
- swtpm 은 에뮬레이트 TPM 으로 libvirt 가 게스트마다 띄운다. 게스트 XML 에는 `<tpm model='tpm-crb'>` 가 필요하다(OS
  프로필이 Windows 11 이면 virt-manager 가 넣는다).
- libvirtd 소켓은 그룹 소유라 libvirtd 그룹이 없으면 qemu:///system 연결마다 root 를 묻는다.

## virtio 드라이버

virtio 는 게스트용 반가상화 디스크·네트워크 장치다. Windows 에는 virtio 드라이버가 없어 virtio 디스크에 바로 올리면
설치 중에 디스크를 못 본다. pkgs.virtio-win 은 .iso 가 아니라 풀린 트리(amd64/w11/..., 최상위
virtio-win-guest-tools.exe)라 그대로 CD-ROM 으로 붙일 게 없다.

게스트 하나면: 드라이버가 필요 없는 SATA + e1000 으로 설치하고 virtio-win-guest-tools.exe 를 돌린 뒤 장치를 옮긴다.
설치 중 virtio 가 필요하면 ISO 를 만든다:

```
xorriso -as mkisofs -o /var/lib/libvirt/images/virtio-win.iso \
  $(nix eval --raw nixpkgs#virtio-win.outPath)
```

## 네트워크

게스트는 기본 NAT 에서 192.168.122.1 로 호스트에 닿는다. nginx 는 0.0.0.0 에 바인드하고 걸리는 건 방화벽뿐이다 —
nginx.nix 가 "LAN 의 다른 기기가 닿아야 할 때만" 열라고 닫아 둔 것의 예외이고, 가상 브리지에 한정한다.

- trustedInterfaces 가 아니라 인터페이스별 443 이다. virbr0 를 믿으면 호스트의 모든 리스닝 포트가 열린다.
- DHCP·DNS 는 libvirt 가 INPUT 맨 위(nixos-fw 앞)에 자기 ACCEPT 를 넣는다.
- spiceUSBRedirection 은 끈다. USB 토큰을 게스트로 넘기는 길이고 일부 공동인증서는 토큰으로 발급되지만, 이 시험의
  인증서는 파일이고 옵션이 setuid spice-client helper 를 끌고 온다.
- `default` NAT 네트워크는 선언하지 않는다(정의는 libvirt 가 싣고 활성화는 런타임 상태 — nginx.nix 와 같은 분리). 첫
  rebuild 뒤 한 번:

```
sudo virsh net-start default
sudo virsh net-autostart default
```
