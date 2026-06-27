import Cocoa
import ApplicationServices
import CoreAudio
import ServiceManagement

// MARK: - Configuration

private let pxPerStepVolume: Double = 48.0
private let pxPerStepBrightness: Double = 11.0
private let volumeStepScale: Float32 = 0.2
private let brightnessStepScale: Float32 = 0.02
private let fallbackMultiplier: Int = 20
private let debugPrints = false


// MARK: - State

private var scrollAccumVolume: Double = 0
private var scrollAccumBrightness: Double = 0
private var eventTap: CFMachPort?
private var cachedDeviceID: AudioDeviceID = 0
private let kVirtualMasterVolume: AudioObjectPropertySelector = 0x766D7663 // 'vmvc'

// MARK: - Volume Control

private func fallbackAppleScriptVolume(deltaSteps: Int) {
    let volDelta = deltaSteps * fallbackMultiplier
    DispatchQueue.global().async {
        let script = "set volume output volume ((output volume of (get volume settings)) + \(volDelta))"
        if let ascr = NSAppleScript(source: script) {
            var error: NSDictionary?
            ascr.executeAndReturnError(&error)
        }
    }
}

private func changeVolume(deltaSteps: Int) {
    guard deltaSteps != 0 else { return }
    let delta = Float32(deltaSteps) * volumeStepScale
    let deviceID = cachedDeviceID
    guard deviceID != 0 else { return }

    var volume: Float32 = 0
    var volumeSize = UInt32(MemoryLayout<Float32>.size)
    var volumeAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: AudioObjectPropertyElement(1)
    )

    var useStereo = true
    var status = AudioObjectGetPropertyData(
        deviceID, &volumeAddr, 0, nil, &volumeSize, &volume
    )
    if status != noErr {
        volumeAddr.mElement = kAudioObjectPropertyElementMain
        useStereo = false
        status = AudioObjectGetPropertyData(
            deviceID, &volumeAddr, 0, nil, &volumeSize, &volume
        )
    }
    if status != noErr {
        volumeAddr.mSelector = kVirtualMasterVolume
        status = AudioObjectGetPropertyData(
            deviceID, &volumeAddr, 0, nil, &volumeSize, &volume
        )
    }
    if status != noErr {
        fallbackAppleScriptVolume(deltaSteps: deltaSteps)
        return
    }

    var isSettable = DarwinBoolean(false)
    let settableStatus = AudioObjectIsPropertySettable(deviceID, &volumeAddr, &isSettable)
    guard settableStatus == noErr, isSettable.boolValue else {
        fallbackAppleScriptVolume(deltaSteps: deltaSteps)
        return
    }

    volume = max(0, min(1, volume + delta))
    AudioObjectSetPropertyData(
        deviceID, &volumeAddr, 0, nil,
        UInt32(MemoryLayout<Float32>.size), &volume
    )
    if useStereo {
        volumeAddr.mElement = AudioObjectPropertyElement(2)
        AudioObjectSetPropertyData(
            deviceID, &volumeAddr, 0, nil,
            UInt32(MemoryLayout<Float32>.size), &volume
        )
    }

    let currentLevel = volume
    DispatchQueue.main.async {
        VolumeHUD.show(level: currentLevel)
    }
}


// MARK: - Device Listener

private let deviceListenerCallback: AudioObjectPropertyListenerProc = { inObjectID, inNumberAddresses, inAddresses, inClientData in
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &addr,
        0, nil, &size, &cachedDeviceID
    )
    return 0
}


// MARK: - Brightness Control

private typealias DisplayServicesGetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
private typealias DisplayServicesSetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

private let displayServices: (get: DisplayServicesGetBrightness?, set: DisplayServicesSetBrightness?) = {
    guard let handle = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        RTLD_LAZY
    ) else { return (nil, nil) }
    guard let symGet = dlsym(handle, "DisplayServicesGetBrightness"),
          let symSet = dlsym(handle, "DisplayServicesSetBrightness") else {
        return (nil, nil)
    }
    let get = unsafeBitCast(symGet, to: DisplayServicesGetBrightness.self)
    let set = unsafeBitCast(symSet, to: DisplayServicesSetBrightness.self)
    return (get, set)
}()

private func changeBrightness(deltaSteps: Int) {
    guard deltaSteps != 0 else { return }
    guard let get = displayServices.get, let set = displayServices.set else { return }

    var brightness: Float = 0
    guard get(CGMainDisplayID(), &brightness) == 0 else { return }

    brightness = max(0, min(1, brightness + Float(deltaSteps) * brightnessStepScale))
    _ = set(CGMainDisplayID(), brightness)
}


// MARK: - Volume HUD

private class VolumeHUDView: NSView {
    var level: Float = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let w = bounds.width
        let h = bounds.height
        let corner: CGFloat = 12

        ctx.saveGState()

        let bgRect = bounds.insetBy(dx: 0, dy: 0)
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: corner, yRadius: corner)
        NSColor.black.withAlphaComponent(0.55).setFill()
        bgPath.fill()

        NSColor.white.withAlphaComponent(0.15).setStroke()
        bgPath.lineWidth = 1
        bgPath.stroke()

        let iconText = "🔊"
        let iconAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20),
            .foregroundColor: NSColor.white.withAlphaComponent(0.9)
        ]
        let iconSize = (iconText as NSString).size(withAttributes: iconAttr)
        let iconX: CGFloat = 20
        let iconY = h - iconSize.height - 22
        (iconText as NSString).draw(at: NSPoint(x: iconX, y: iconY), withAttributes: iconAttr)

        let barH: CGFloat = 6
        let barY: CGFloat = 16
        let barInset: CGFloat = 20
        let barW = w - barInset * 2

        let barBgPath = NSBezierPath(roundedRect:
            NSRect(x: barInset, y: barY, width: barW, height: barH),
            xRadius: barH / 2, yRadius: barH / 2)
        NSColor.white.withAlphaComponent(0.15).setFill()
        barBgPath.fill()

        let fillW = max(barH, barW * CGFloat(level))
        if fillW > 0 {
            let fillPath = NSBezierPath(roundedRect:
                NSRect(x: barInset, y: barY, width: fillW, height: barH),
                xRadius: barH / 2, yRadius: barH / 2)
            NSColor.white.withAlphaComponent(0.9).setFill()
            fillPath.fill()
        }

        ctx.restoreGState()
    }
}

private struct VolumeHUD {
    private static let window: NSWindow = {
        let size = NSSize(width: 260, height: 72)
        let rect = NSRect(origin: .zero, size: size)
        let w = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        w.level = .floating
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.alphaValue = 0
        w.ignoresMouseEvents = true
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let v = VolumeHUDView(frame: rect)
        v.wantsLayer = true
        w.contentView = v

        return w
    }()

    private static var hideTimer: DispatchWorkItem?

    static func show(level: Float) {
        dispatchPrecondition(condition: .onQueue(.main))

        guard let v = window.contentView as? VolumeHUDView else { return }
        v.level = level
        v.needsDisplay = true

        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main!
        let screenFrame = screen.frame

        let originX = (screenFrame.width - window.frame.width) / 2 + screenFrame.origin.x
        let originY = screenFrame.origin.y + screenFrame.height - window.frame.height - 60

        window.setFrameOrigin(NSPoint(x: originX, y: originY))

        if window.alphaValue < 0.5 {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.15
                window.animator().alphaValue = 1.0
            }, completionHandler: {})
        }

        hideTimer?.cancel()
        let work = DispatchWorkItem {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                window.animator().alphaValue = 0.0
            }, completionHandler: {})
        }
        hideTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }
}


// MARK: - Permission Check
private func checkAccessibility(prompt: Bool) -> Bool {
    let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let opts: CFDictionary = [key: prompt] as CFDictionary
    return AXIsProcessTrustedWithOptions(opts)
}

// MARK: - Event Tap Callback

private let eventCallback: CGEventTapCallBack = { proxy, type, event, refcon in
    switch type {
    case .scrollWheel:
        let flags = event.flags
        guard flags.contains(.maskSecondaryFn) else {
            return Unmanaged.passUnretained(event)
        }

        let deltaY = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
        let deltaX = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
        let absY = abs(deltaY)
        let absX = abs(deltaX)

        if absX > absY {
            scrollAccumBrightness -= deltaX
            let steps = max(-5, min(5, Int(scrollAccumBrightness / pxPerStepBrightness)))
            if steps != 0 {
                changeBrightness(deltaSteps: steps)
                if debugPrints {
                    let dir = steps > 0 ? "right" : "left"
                    print("  Fn+horizontal \(dir): brightness (\(abs(steps)) step\(abs(steps) == 1 ? "" : "s"))")
                    fflush(stdout)
                }
                scrollAccumBrightness -= Double(steps) * pxPerStepBrightness
            }
        } else if absY > absX {
            scrollAccumVolume += deltaY
            let steps = max(-1, min(1, Int(scrollAccumVolume / pxPerStepVolume)))
            if steps != 0 {
                changeVolume(deltaSteps: steps)
                if debugPrints {
                    print("  Fn+scroll \(steps > 0 ? "up" : "down"): volume")
                    fflush(stdout)
                }
                scrollAccumVolume -= Double(steps) * pxPerStepVolume
            }
        }

        return nil

    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)

    default:
        break
    }
    return Unmanaged.passUnretained(event)
}

// MARK: - Status Bar Icon

private func statusBarIcon() -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size)
    image.isTemplate = true

    image.lockFocus()

    let rect = NSRect(x: 1.5, y: 1.5, width: 15, height: 15)
    let trackpad = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
    trackpad.lineWidth = 1.5
    NSColor.black.setStroke()
    trackpad.stroke()

    let chevron = NSBezierPath()
    chevron.move(to: NSPoint(x: 5, y: 7))
    chevron.line(to: NSPoint(x: 9, y: 11))
    chevron.line(to: NSPoint(x: 13, y: 7))
    chevron.lineWidth = 1.5
    chevron.lineCapStyle = .round
    chevron.lineJoinStyle = .round
    NSColor.black.setStroke()
    chevron.stroke()

    image.unlockFocus()
    return image
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var launchAtLoginItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()

        if !checkAccessibility(prompt: false) {
            return
        }

        setupEventTap()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                sender.state = .off
            } else {
                try SMAppService.mainApp.register()
                sender.state = .on
            }
        } catch {
            if debugPrints { print("Launch at Login toggle failed: \(error)") }
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = statusBarIcon()

        let menu = NSMenu()

        launchAtLoginItem = NSMenuItem(title: "Launch at Login",
                                       action: #selector(toggleLaunchAtLogin(_:)),
                                       keyEquivalent: "")
        launchAtLoginItem?.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launchAtLoginItem!)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))

        statusItem?.menu = menu
    }
}

// MARK: - Event Tap Setup

private func setupEventTap() {
    var initialSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    var initialAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &initialAddr,
        0, nil, &initialSize, &cachedDeviceID
    )
    AudioObjectAddPropertyListener(
        AudioObjectID(kAudioObjectSystemObject), &initialAddr,
        deviceListenerCallback, nil
    )

    let eventMask = (1 << CGEventType.scrollWheel.rawValue) as CGEventMask

    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: eventCallback,
        userInfo: nil
    ) else {
        return
    }
    eventTap = tap

    let rls = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, .commonModes)
}

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
