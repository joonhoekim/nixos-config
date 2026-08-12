# ./shaders 의 출처

이 폴더의 셰이더 중 crt 갈래는 파생 저작물이고, 이 파일은 그 사실을 적어 두려고
있다. `./shaders/crt/crt.frag` 의 머리말이 `../../SHADER-CREDITS.md` 로 가리키는
자리가 여기다. (이름이 LICENSE 였는데, 라이선스 본문이 아니라 출처 메모라서
도구들이 프로젝트 라이선스로 오독하지 않게 바꿨다.)

**Maxim Samoliuk — Hyprland 화면 셰이더 (MIT)**, "space_dots (Golden Era)"
라이스(https://github.com/vdawg-git/space_dots)에 실려 있던 것.
`./shaders/crt/crt.frag` 은 이 레포의 터미널 셰이더
(`../../../shared/ghostty/shaders/crt.glsl`)를 거쳐 거기까지 거슬러 올라간다.

블룸 표본, 필름 그레인, 깜빡임, 색수차, 가장자리 감쇠는 전부 다시 짰다 —
무엇을 왜 바꿨는지는 `crt.glsl` 과 `crt.frag` 의 머리말에 적혀 있다. 그래도
계보는 실재하므로 여기 밝혀 둔다. 상류가 MIT 이므로 이 고지로 조건을 만족한다.

물·사이버펑크·인쇄 세 갈래는 위 계보와 무관하게 새로 쓴 것이라 여기 안 나온다.

---

이 폴더의 셰이더는 `~/git/global-shader-for-macos` 와 같은 파일이다. 그쪽은
맥에 없는 `decoration:screen_shader` 를 캡처 + 오버레이로 흉내 내는 프로그램
이고, 규약을 하이프랜드에 맞춰 뒀기 때문에 파일이 양쪽에서 그대로 돈다.
그쪽 LICENSE 도 같은 내용을 담고 있다.
