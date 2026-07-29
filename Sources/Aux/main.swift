import AppKit

// Hidden developer flags, used by CI and the build tooling.
if CommandLine.arguments.contains("--smoke-test") {
    exit(runSmokeTest())
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
