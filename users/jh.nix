# 계약은 ./README.md 에 있다.
{
  name = "jh";

  git = {
    name = "joonhoekim";
    email = "26rote@gmail.com";
  };

  # 비어 있으면 sshd 는 비밀번호 로그인만 받는다 (hosts/nixos/common.nix 의
  # openssh 블록 참고).
  authorizedKeys = [ ];
}
