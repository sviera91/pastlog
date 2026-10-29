import AppKit

let arguments = CommandLine.arguments
let app = NSApplication.shared

if let i = arguments.firstIndex(of: "--render-icon"), arguments.count > i + 1 {
    let art = arguments.firstIndex(of: "--art").flatMap { arguments.count > $0 + 1 ? arguments[$0 + 1] : nil }
    MainActor.assumeIsolated { DevTools.renderIcon(to: arguments[i + 1], art: art) }
    exit(0)
}
if let i = arguments.firstIndex(of: "--snapshot"), arguments.count > i + 1 {
    let fonts = arguments.firstIndex(of: "--fonts").flatMap { arguments.count > $0 + 1 ? arguments[$0 + 1] : nil }
    app.setActivationPolicy(.accessory)
    MainActor.assumeIsolated { DevTools.renderSnapshots(to: arguments[i + 1], fonts: fonts) }
    exit(0)
}

let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
