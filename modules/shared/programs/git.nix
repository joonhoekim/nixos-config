# Git configuration. Returns a `programs`-shaped fragment.
{ ... }:
let
  name = "joonhoekim";
  email = "26rote@gmail.com";
in
{
  git = {
    enable = true;
    ignores = [ "*.swp" ];
    lfs.enable = true;
    settings = {
      user.name = name;
      user.email = email;
      init.defaultBranch = "main";
      core = {
        editor = "vim";
        autocrlf = "input";
      };
      pull.rebase = true;
      rebase.autoStash = true;
      credential = {
        "https://github.com".helper = "!gh auth git-credential";
        "https://gist.github.com".helper = "!gh auth git-credential";
      };
    };
  };
}
