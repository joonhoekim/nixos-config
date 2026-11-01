# 로그인 셸은 macOS·NixOS 모두 bash 다. zsh 설정은 zsh 를 직접 띄웠을 때만 쓰인다.
{ pkgs, lib, bundles, ... }:
{
  bash = {
    enable = true;
    historyControl = [ "ignoredups" "erasedups" ];
    historySize = 50000;
    historyFileSize = 50000;
    initExtra = import ../shell-init.nix { inherit pkgs lib bundles; };

    # macOS /etc/profile 의 path_helper 가 /usr/bin 을 PATH 앞으로 올리는데, nix 환경을 물려받은 로그인 셸
    # (tmux 새 창)에서는 /etc/bashrc 가 __NIX_DARWIN_SET_ENVIRONMENT_DONE 로 건너뛰어 git·jq 가 조용히
    # /usr/bin 것이 된다. 시스템 디렉토리만 뒤로 보내고 물려받은 나머지 순서는 둔다.
    profileExtra = lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      if [ -x /usr/libexec/path_helper ]; then
        __sys=":/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:"
        __head=""; __tail=""
        IFS=:
        for __d in $PATH; do
          case "$__sys" in
            *":$__d:"*) __tail="$__tail:$__d" ;;
            *) __head="$__head:$__d" ;;
          esac
        done
        unset IFS
        PATH="''${__head#:}$__tail"
        unset __sys __head __tail __d
      fi
    '';
  };

  # p10k 는 zsh 전용이라 bash 는 starship. zsh 통합을 켜면 .zshrc 끝에서 p10k 프롬프트를 덮는다.
  starship = {
    enable = true;
    enableZshIntegration = false;
  };
}
