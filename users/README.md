# users/

한 파일이 한 사람이다. 유저명, git 신원, 그리고 이 계정으로 들어올 수 있는 SSH
공개키 — 기계마다 달라지지 않고 **사람마다** 달라지는 값만 여기 있다.

호스트는 자기 디렉토리의 `identity.nix` 한 줄로 쓸 사람을 고른다 —
`hosts/<플랫폼>/<hostname>/identity.nix`:

```nix
import ../../../users/hong.nix
```

전용 디렉토리가 없는 Mac 이 쓰는 공용 설정만 한 단계 위의
`hosts/darwin/identity.nix` 이고, 그래서 경로도 `../../users/` 다.

`default.nix` 안이 아니라 별도 파일인 이유는 `flake.nix` 에 적혀 있다 —
모듈이 평가되기 전에 정해져야 하는 값이다.

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
