// LaunchServices 가 각 UTI 를 실제로 어느 앱으로 여는지 출력한다.
//
//   swift handlers.swift public.toml public.css ...
//   → public.toml<TAB>com.microsoft.VSCode
//
// plist 에 적힌 값이 아니라 해석 결과를 본다. modules/darwin/default-apps.nix 에
// 적은 대로 plist 항목이 맞아도 LaunchServices 캐시가 옛 앱을 돌려줄 수 있고,
// 사용자가 겪는 것은 그 해석 결과다.
//
// LSCopyDefaultRoleHandlerForContentType 이 아니라 NSWorkspace 를 쓰는 이유:
// 전자는 deprecated 이고, macOS 26 + Xcode 툴체인의 `swift <파일>` 은 그 호출에서
// "failed to produce diagnostic" 으로 멈춘다(2026-09-28 실측).

import AppKit
import UniformTypeIdentifiers

for uti in CommandLine.arguments.dropFirst() {
  var id = "-"
  if let t = UTType(uti), let u = NSWorkspace.shared.urlForApplication(toOpen: t) {
    id = Bundle(url: u)?.bundleIdentifier ?? u.path
  }
  print("\(uti)\t\(id)")
}
