# Git configuration. Returns a `programs`-shaped fragment.
#
# 이름과 메일은 사람마다 다른 값이라 여기 없다 — users/<이름>.nix 가 들고 있고
# (users/README.md), 그래야 포크하는 쪽이 공유 모듈을 고치지 않는다.
{ identity, ... }:
{
  git = {
    enable = true;
    ignores = [ "*.swp" ];
    lfs.enable = true;
    settings = {
      user.name = identity.git.name;
      user.email = identity.git.email;
      init.defaultBranch = "main";
      core = {
        editor = "vim";
        autocrlf = "input";
      };
      pull.rebase = true;
      push.autoSetupRemote = true;
      rebase.autoStash = true;
      credential = {
        "https://github.com".helper = "!gh auth git-credential";
        "https://gist.github.com".helper = "!gh auth git-credential";
      };
    };
  };
}
