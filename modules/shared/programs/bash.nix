# Shared bash configuration. Returns a `programs`-shaped fragment merged by
# modules/shared/home-manager.nix.
#
# macOS 에서는 로그인 셸이 bash 다(modules/darwin/home-manager.nix). NixOS 는
# 아직 zsh 이고, 거기서 이 설정은 bash 를 직접 띄웠을 때만 쓰인다.
{ pkgs, lib, ... }:
{
  bash = {
    enable = true;
    historyControl = [ "ignoredups" "erasedups" ];
    historySize = 50000;
    historyFileSize = 50000;
    initExtra = import ../shell-init.nix { inherit pkgs lib; };

    # macOS 의 /etc/profile 은 로그인 bash 마다 path_helper 를 돌려 /usr/bin 등을
    # PATH 맨 앞으로 올린다. 새 터미널에서는 뒤이어 nix-darwin 의 /etc/bashrc 가
    # PATH 를 다시 쓰므로 괜찮지만, nix 환경을 물려받은 로그인 셸(tmux 새 창 등)
    # 에서는 그게 "이미 했다"(__NIX_DARWIN_SET_ENVIRONMENT_DONE)며 건너뛰어서
    # git·jq 가 조용히 /usr/bin 의 것으로 바뀐다. zsh 는 nix-darwin 이 /etc/zprofile
    # 을 대신 써서 path_helper 가 돌지 않으므로 bash 에만 있는 문제다.
    #
    # 순서를 통째로 다시 쓰지 않고 시스템 디렉토리만 뒤로 보낸다 — 물려받은
    # 나머지 경로(VS Code·mise 가 넣은 것)는 그대로 둔다.
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

  # bash 의 프롬프트. p10k 는 zsh 전용이라 bash 에는 이걸 쓴다. zsh 통합은 끈다 —
  # 켜 두면 .zshrc 끝에서 starship 이 p10k 의 프롬프트를 덮어쓴다.
  starship = {
    enable = true;
    enableZshIntegration = false;
  };
}
