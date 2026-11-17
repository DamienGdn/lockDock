import Cocoa
import ServiceManagement

// lockDock : empêche le Dock de se déplacer sur un autre écran.
// Tout l'état ci-dessous est lu/écrit sur le thread principal (le tap y est branché).

enum Edge { case bottom, left, right }

let defaults = UserDefaults.standard

var lockEnabled = defaults.object(forKey: "enabled") as? Bool ?? true {
    didSet { defaults.set(lockEnabled, forKey: "enabled") }
}
var margin: CGFloat = {
    let v = defaults.double(forKey: "margin")
    return v > 0 ? CGFloat(v) : 4
}() {
    didSet { defaults.set(Double(margin), forKey: "margin") }
}
var dockEdge = Edge.bottom
var allRects: [CGRect] = []      // tous les écrans actifs
var guardedRects: [CGRect] = []  // écrans où le Dock ne doit pas apparaître
var tap: CFMachPort?

// MARK: écrans

func activeDisplays() -> [CGDirectDisplayID] {
    var ids = [CGDirectDisplayID](repeating: 0, count: 16)
    var n: UInt32 = 0
    CGGetActiveDisplayList(16, &ids, &n)
    return Array(ids.prefix(Int(n)))
}

func uuid(of id: CGDirectDisplayID) -> String? {
    guard let u = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
    return CFUUIDCreateString(nil, u) as String
}

/// Écran qui garde le Dock : celui choisi dans le menu, sinon l'écran principal.
func keepDisplayID() -> CGDirectDisplayID {
    if let s = defaults.string(forKey: "keepDisplay"),
       let id = activeDisplays().first(where: { uuid(of: $0) == s }) { return id }
    return CGMainDisplayID()
}

/// Recalcule les écrans protégés et la position du Dock (appelé périodiquement).
func refreshState() {
    let ids = activeDisplays()
    let keep = keepDisplayID()
    allRects = ids.map { CGDisplayBounds($0) }
    guardedRects = ids.filter { $0 != keep }.map { CGDisplayBounds($0) }
    let o = CFPreferencesCopyAppValue("orientation" as CFString, "com.apple.dock" as CFString) as? String
    dockEdge = o == "left" ? .left : (o == "right" ? .right : .bottom)
}

// MARK: blocage du curseur

/// Renvoie la position corrigée si le curseur touche le bord « Dock » d'un écran protégé.
/// Un bord partagé avec un autre écran reste franchissable : seul un bord extérieur est bloqué.
func clamp(_ p: CGPoint) -> CGPoint? {
    for r in guardedRects where r.contains(p) {
        var q = p
        switch dockEdge {
        case .bottom:
            guard p.y > r.maxY - margin, !allRects.contains(where: { $0.contains(CGPoint(x: p.x, y: r.maxY + 1)) }) else { continue }
            q.y = r.maxY - margin
        case .left:
            guard p.x < r.minX + margin, !allRects.contains(where: { $0.contains(CGPoint(x: r.minX - 1, y: p.y)) }) else { continue }
            q.x = r.minX + margin
        case .right:
            guard p.x > r.maxX - margin, !allRects.contains(where: { $0.contains(CGPoint(x: r.maxX + 1, y: p.y)) }) else { continue }
            q.x = r.maxX - margin
        }
        return q
    }
    return nil
}

let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    // Option maintenue : on laisse passer.
    if !lockEnabled || event.flags.contains(.maskAlternate) { return Unmanaged.passUnretained(event) }
    if let q = clamp(event.location) {
        event.location = q
        CGWarpMouseCursorPosition(q)
    }
    return Unmanaged.passUnretained(event)
}

// MARK: app

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var item: NSStatusItem!

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

        refreshState()
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in refreshState() }

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        setIcon()
    }

    func setIcon() {
        let img = NSImage(systemSymbolName: lockEnabled ? "lock.display" : "display", accessibilityDescription: "lockDock")
        img?.isTemplate = true
        item.button?.image = img
    }

    // Le menu est reconstruit à chaque ouverture (liste d'écrans à jour).
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let toggle = NSMenuItem(title: "Verrouiller le Dock", action: #selector(flip), keyEquivalent: "")
        toggle.target = self
        toggle.state = lockEnabled ? .on : .off
        menu.addItem(toggle)

        let screens = NSMenuItem(title: "Écran qui garde le Dock", action: nil, keyEquivalent: "")
        let screensMenu = NSMenu()
        let keep = keepDisplayID()
        for s in NSScreen.screens {
            guard let id = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { continue }
            let it = NSMenuItem(title: s.localizedName, action: #selector(pickScreen(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = uuid(of: id)
            it.state = id == keep ? .on : .off
            screensMenu.addItem(it)
        }
        screens.submenu = screensMenu
        menu.addItem(screens)

        let marginItem = NSMenuItem(title: "Marge du bord", action: nil, keyEquivalent: "")
        let marginMenu = NSMenu()
        for v in [2, 4, 8, 16, 32] {
            let it = NSMenuItem(title: "\(v) px", action: #selector(pickMargin(_:)), keyEquivalent: "")
            it.target = self
            it.tag = v
            it.state = CGFloat(v) == margin ? .on : .off
            marginMenu.addItem(it)
        }
        marginItem.submenu = marginMenu
        menu.addItem(marginItem)

        let login = NSMenuItem(title: "Lancer au démarrage", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.isEnabled = Bundle.main.bundleURL.pathExtension == "app"
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let edge = dockEdge == .bottom ? "en bas" : (dockEdge == .left ? "à gauche" : "à droite")
        let info = NSMenuItem(title: "Dock \(edge) · maintenir ⌥ pour passer", action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)
        menu.addItem(withTitle: "Quitter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc func flip() { lockEnabled.toggle(); setIcon() }

    @objc func pickScreen(_ s: NSMenuItem) {
        defaults.set(s.representedObject as? String, forKey: "keepDisplay")
        refreshState()
    }

    @objc func pickMargin(_ s: NSMenuItem) { margin = CGFloat(s.tag) }

    @objc func toggleLogin() {
        let s = SMAppService.mainApp
        do {
            if s.status == .enabled { try s.unregister() } else { try s.register() }
        } catch {
            NSLog("Lancement au démarrage impossible : \(error)")
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = App()
app.delegate = delegate
app.run()
