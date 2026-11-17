import Cocoa

// Empêche le curseur de toucher le bord bas des écrans secondaires,
// donc le Dock (en bas) ne peut plus s'y déplacer.
let margin: CGFloat = 4

func secondaryDisplays() -> [CGRect] {
    var ids = [CGDirectDisplayID](repeating: 0, count: 16)
    var n: UInt32 = 0
    CGGetActiveDisplayList(16, &ids, &n)
    return ids.prefix(Int(n)).filter { $0 != CGMainDisplayID() }.map { CGDisplayBounds($0) }
}

var tap: CFMachPort?
var enabled = true

let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    guard enabled else { return Unmanaged.passUnretained(event) }
    var p = event.location
    for r in secondaryDisplays() where r.contains(p) && p.y > r.maxY - margin {
        p.y = r.maxY - margin
        event.location = p
        CGWarpMouseCursorPosition(p)
        break
    }
    return Unmanaged.passUnretained(event)
}

final class App: NSObject, NSApplicationDelegate {
    var item: NSStatusItem!
    var toggle: NSMenuItem!

    @objc func flip() {
        enabled.toggle()
        toggle.state = enabled ? .on : .off
        setIcon()
    }
    func setIcon() {
        let name = enabled ? "lock.display" : "display"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "DockLock")
        img?.isTemplate = true
        item.button?.image = img
    }
    func applicationDidFinishLaunching(_ n: Notification) {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(opts) else {
            NSLog("Permission Accessibilité requise, relancer après l'avoir accordée.")
            NSApp.terminate(nil); return
        }
        let mask: CGEventMask = [CGEventType.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
            .reduce(0) { $0 | (1 << $1.rawValue) }
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                        options: .defaultTap, eventsOfInterest: mask,
                                        callback: callback, userInfo: nil) else {
            NSLog("Création du tap impossible"); NSApp.terminate(nil); return
        }
        tap = t
        CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        toggle = NSMenuItem(title: "Verrouiller le Dock sur l'écran principal", action: #selector(flip), keyEquivalent: "")
        toggle.target = self
        toggle.state = .on
        menu.addItem(toggle)
        setIcon()
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quitter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = App()
app.delegate = delegate
app.run()
