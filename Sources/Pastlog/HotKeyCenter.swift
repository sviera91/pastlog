import AppKit
import Carbon.HIToolbox

/// Global hotkeys via Carbon's RegisterEventHotKey (needs no Accessibility permission).
@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var refs: [UInt32: EventHotKeyRef] = [:]
    fileprivate var handlers: [UInt32: () -> Void] = [:]
    private var installed = false

    func register(id: UInt32, shortcut: Shortcut?, handler: @escaping () -> Void) {
        unregister(id)
        guard let shortcut else { return }
        installIfNeeded()
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x5053_544C), id: id) // "PSTL"
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            refs[id] = ref
            handlers[id] = handler
        } else {
            NSLog("Pastlog: could not register hotkey \(shortcut.display) (status \(status))")
        }
    }

    func unregister(_ id: UInt32) {
        if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
        handlers[id] = nil
    }

    private func installIfNeeded() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let id = hotKeyID.id
            DispatchQueue.main.async {
                MainActor.assumeIsolated { HotKeyCenter.shared.handlers[id]?() }
            }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
