# 무엇을 어느 기계에 깔까 — 메모리·디스크 기준

가벼운 기계(MacBook Air, Galaxy Chromebook 1)에 무엇을 깔고 무엇을 뺄지 정하는
기준. 숫자는 `nix run .#footprint -- <호스트>` 로 다시 잰다.

## 한 줄 요약

**깔려 있기만 한 패키지는 메모리를 쓰지 않는다.** 그래서 기계마다 무엇을 깔지는
디스크로 정한다. 예외는 부팅 때 스스로 뜨는 서비스뿐이고, 그런 것은 그것을 쓰는
묶음에 묶어 둔다.

## 메모리: 세 종류

| 종류 | 예 | 어떻게 다루나 |
|---|---|---|
| 깔기만 해도 상주한다 | docker 데몬(dockerd·containerd) | 그것을 쓰는 묶음을 고른 호스트에서만 켠다. docker 는 `containers` 묶음에 묶여 있다(`hosts/nixos/common.nix`) |
| 한 번 쓰면 뒤에 남는다 | eslint_d · prettierd(web), watchman(mobile), colima 의 VM(containers, macOS) | 깔려 있는 것과는 상관없다. 쓰고 나서 남은 프로세스를 끝내면 된다 |
| 쓸 때만 쓴다 | 나머지 전부. 브라우저·Electron 앱(VS Code, bruno)·JVM 앱(dbeaver, maestro)이 무겁다 | 설치를 빼서 아낄 메모리는 없다. 안 띄우면 0 이다 |

데스크톱 자체(셸, 입력기, thermald 등)도 상주하지만, 그건 패키지 선택이 아니라
세션 구성의 문제라 여기서 다루지 않는다.

## 디스크: core 위에 더해지는 양

galaxy-chromebook-1(x86_64-linux), nixpkgs `efe6f07`, 2026-11-01 측정. 같은 라이브러리를
core 가 이미 끌어왔으면 그만큼은 세지 않은 값이다. 크기는 cache.nixos.org 의 narSize
(압축을 푼 크기). core 자체는 2.7 GiB 이고, 캐시에 없는 python 환경은 빠져 있다.

| CLI 묶음 | +GiB | 크기의 대부분 |
|---|---:|---|
| web | 2.3 | playwright 의 브라우저들 |
| containers | 2.0 | colima·lima 가 끌어오는 qemu |
| documents | 1.7 | d2 1.5 (아래), pandoc |
| toys | 1.7 | vhs 1.0 |
| mobile-e2e | 0.9 | maestro(JDK) |
| backend | 0.8 | seaweedfs, buf |
| security | 0.7 | semgrep, trivy |
| media | 0.7 | streamlink, gifski, ffmpeg |
| cloud | 0.6 | k9s, awscli2 |
| mobile | 0.5 | scrcpy |

| GUI 앱 (NixOS) | +GiB |
|---|---:|
| krita | 2.0 |
| gimp | 1.1 |
| bruno · dbeaver-bin · brave | 각 0.9 |
| zed-editor · firefox-devedition | 각 0.8 |
| inkscape | 0.6 |
| mpv · resources · mission-center · ghostty | 각 0.3~0.4 |
| zathura | 0.05 |

vscode · google-chrome · onlyoffice · redisinsight 는 unfree 라 캐시에 없어서 크기를
모른다. 상류가 내놓은 바이너리를 풀기만 하므로 기계가 빌드하지는 않는다.

macOS 의 cask 는 nix 밖이라 이 도구로 잴 수 없다.

## 기준

1. **부팅 때 스스로 뜨는 서비스는 core 에 두지 않는다.** 그것을 쓰는 묶음에 묶는다.
2. **core 에는 혼자 100 MiB 넘게 더하는 것을 두지 않는다.** core 는 가장 가벼운
   기계에도 깔리는 자리라서, 넘으면 쓰임새가 같은 묶음으로 옮긴다. d2 가 이렇게
   documents 로 갔다 — Linux 판이 PNG 내보내기용 브라우저 셋을 끌어와 1.5 GiB 다
   (macOS 판은 61 MiB).
3. **약한 기계에는 그 기계가 직접 빌드해야 하는 것을 피한다.** 캐시에 없고 unfree 도
   아닌 것이 그렇다 — 지금은 documents 의 ocrmypdf·tesseract(언어를 줄인 override)이고,
   nixpkgs 를 올릴 때마다 시험까지 다시 돈다.
4. **쓸 때만 메모리를 쓰는 앱은 디스크로만 판단한다.**

## 지금 가벼운 기계가 고른 것

| | CLI 묶음 | GUI (core 외) |
|---|---|---|
| jhs-MacBook-Air | media mobile toys | 브라우저 셋, onlyoffice, dbeaver |

모든 기계에 깔리는 GUI core 는 macOS 에서 VS Code, NixOS 에서 VS Code 와 ghostty
(`apps/rice/wall --yazi` 가 띄운다)다. 호스트별 현황은 `nix run .#inventory`.
