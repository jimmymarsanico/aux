import AppKit

// Hidden developer flags, used by CI and the build tooling.
if CommandLine.arguments.contains("--smoke-test") {
    exit(runSmokeTest())
}
if let flagIndex = CommandLine.arguments.firstIndex(of: "--dump-icons"),
   CommandLine.arguments.indices.contains(flagIndex + 1) {
    exit(dumpIcons(to: CommandLine.arguments[flagIndex + 1]))
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
