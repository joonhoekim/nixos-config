# users/

한 파일이 한 사람이다. 유저명, git 신원, 그리고 이 계정으로 들어올 수 있는 SSH
공개키 — 기계마다 달라지지 않고 **사람마다** 달라지는 값만 여기 있다.

호스트는 `hosts/nixos/<hostname>/default.nix` 에서 자기가 쓸 사람을 고른다:

```nix
identity = import ../../../users/hong.nix;
```

포크하는 쪽이 만드는 파일이 바로 이것이다. upstream 이 계속 고치는 파일
(`flake.nix`, `modules/`)에는 손대지 않으므로 `git pull` 이 충돌하지 않는다.
`./apps/setup` 이 이 파일과 호스트 디렉토리를 같이 만들어 준다.

## 계약

| 키 | 필수 | 쓰이는 곳 |
|---|---|---|
| `name` | O | 계정 이름. `users.users.<name>`, `/home/<name>`(macOS 는 `/Users/<name>`), sudoers, nix `trusted-users` |
| `git.name` / `git.email` | O | `modules/shared/programs/git.nix` → `~/.gitconfig` |
| `authorizedKeys` | | `users.users.<name>.openssh.authorizedKeys.keys`. 빈 목록이면 비밀번호 로그인만 된다 |

비밀번호는 여기 없다. 공개 저장소라 해시도 안 넣는다 — 첫 switch 뒤 root 로
`passwd <name>` 을 한 번 친다(`./apps/doctor` 가 잠긴 계정을 짚어 준다).
