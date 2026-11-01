# 이름·메일은 users/<이름>.nix 가 든다(users/README.md) — 포크가 공유 모듈을 안 고치게.
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
