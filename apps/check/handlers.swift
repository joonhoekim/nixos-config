// LaunchServices 가 각 UTI 를 실제로 어느 앱으로 여는지 출력한다: `swift handlers.swift public.toml` → public.toml<TAB>com.microsoft.VSCode
// plist 항목이 맞아도 LaunchServices 캐시가 옛 앱을 돌려줄 수 있어서 해석 결과를 본다.
// LSCopyDefaultRoleHandlerForContentType 은 deprecated 이고, macOS 26 의 `swift <파일>` 이 그 호출에서
// "failed to produce diagnostic" 으로 멈춘다(2026-09-28 실측). 그래서 NSWorkspace 를 쓴다.

import AppKit
import UniformTypeIdentifiers

for uti in CommandLine.arguments.dropFirst() {
  var id = "-"
  if let t = UTType(uti), let u = NSWorkspace.shared.urlForApplication(toOpen: t) {
    id = Bundle(url: u)?.bundleIdentifier ?? u.path
  }
  print("\(uti)\t\(id)")
}
