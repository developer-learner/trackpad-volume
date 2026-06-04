import Cocoa
import ApplicationServices
import CoreAudio

// MARK: - Configuration

private let pxPerStepVolume: Double = 48.0
private let pxPerStepBrightness: Double = 11.0


// MARK: - State

private var scrollAccumVolume: Double = 0
private var scrollAccumBrightness: Double = 0
private var eventTap: CFMachPort?
private var cachedDeviceID: AudioDeviceID = 0
private let kVirtualMasterVolume: AudioObjectPropertySelector = 0x766D7663 // 'vmvc'

// MARK: - Volume Control

private func changeVolume(deltaSteps: Int) {
    guard deltaSteps != 0 else { return }
    let delta = Float32(deltaSteps) * 0.16
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
        let volDelta = deltaSteps * 16
        DispatchQueue.global().async {
            let script = "set volume output volume ((output volume of (get volume settings)) + \(volDelta))"
            if let ascr = NSAppleScript(source: script) {
                var error: NSDictionary?
                ascr.executeAndReturnError(&error)
            }
        }
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
    // dlopen from the dyld shared cache — the framework binary may not exist on disk
    // on macOS 26+ (Tahoe) but the symbols are in the shared cache.
    guard let handle = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        RTLD_LAZY
    ) else { return (nil, nil) }
    let get = unsafeBitCast(dlsym(handle, "DisplayServicesGetBrightness"), to: DisplayServicesGetBrightness?.self)
    let set = unsafeBitCast(dlsym(handle, "DisplayServicesSetBrightness"), to: DisplayServicesSetBrightness?.self)
    return (get, set)
}()

private func changeBrightness(deltaSteps: Int) {
    guard deltaSteps != 0 else { return }
    guard let get = displayServices.get, let set = displayServices.set else { return }

    var brightness: Float = 0
    guard get(CGMainDisplayID(), &brightness) == 0 else { return }

    brightness = max(0, min(1, brightness + Float(deltaSteps) * 0.02))
    _ = set(CGMainDisplayID(), brightness)
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

        let isBrightness = flags.contains(.maskAlternate)
        let delta = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
        guard abs(delta) > 0 else {
            return nil
        }

        if isBrightness {
            scrollAccumBrightness += delta
            let steps = max(-5, min(5, Int(scrollAccumBrightness / pxPerStepBrightness)))
            if steps != 0 {
                changeBrightness(deltaSteps: steps)
                let dir = steps > 0 ? "up" : "down"
                print("  Fn+⌥+ scroll \(dir): brightness (\(abs(steps)) step\(abs(steps) == 1 ? "" : "s"))")
                fflush(stdout)
                scrollAccumBrightness -= Double(steps) * pxPerStepBrightness
            }
        } else {
            scrollAccumVolume += delta
            let steps = max(-1, min(1, Int(scrollAccumVolume / pxPerStepVolume)))
            if steps != 0 {
                changeVolume(deltaSteps: steps)
                print("  Fn+scroll \(steps > 0 ? "up" : "down"): volume")
                fflush(stdout)
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

// MARK: - Main

func main() {
    print("trackpad-volume — Fn+scroll volume & brightness")
    print("")

    let trusted = checkAccessibility(prompt: false)
    if !trusted {
        print("⚠️  Accessibility NOT granted")
        _ = checkAccessibility(prompt: true)
        exit(1)
    }
    print("✅ Accessibility permission: granted")
    print("")

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
        print("error: cannot create event tap")
        exit(1)
    }
    eventTap = tap

    let rls = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, .commonModes)

    print("listening...")
    print("  Fn     + two-finger scroll up/down → volume")
    print("  Fn+⌥   + two-finger scroll up/down → brightness")
    print("  (scroll is suppressed — page won't move)")
    print("  Regular scroll without Fn → normal scrolling")
    print("")
    print("  press ^C to quit")
    fflush(stdout)

    CFRunLoopRun()
}

main()
