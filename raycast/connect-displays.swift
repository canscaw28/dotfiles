#!/usr/bin/env swift

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Connect Displays
// @raycast.mode silent

// Optional parameters:
// @raycast.icon 🖥
// @raycast.packageName Display

import Foundation

// Sidecar supports only one simultaneous connection, so target a specific iPad.
// The other iPad is handled by Duet's Air Auto-Connect.
let sidecarTarget = "CW iPad"

if let bundle = Bundle(path: "/System/Library/PrivateFrameworks/SidecarCore.framework"), bundle.load(),
   let managerClass = NSClassFromString("SidecarDisplayManager") as? NSObject.Type,
   let manager = managerClass.perform(NSSelectorFromString("sharedManager"))?.takeUnretainedValue() as? NSObject {

    let devices = manager.perform(NSSelectorFromString("devices"))?.takeUnretainedValue() as? [NSObject] ?? []
    let connected = manager.perform(NSSelectorFromString("connectedDevices"))?.takeUnretainedValue() as? [NSObject] ?? []

    let alreadyConnected = connected.contains {
        ($0.perform(NSSelectorFromString("name"))?.takeUnretainedValue() as? String) == sidecarTarget
    }
    let target = devices.first {
        ($0.perform(NSSelectorFromString("name"))?.takeUnretainedValue() as? String) == sidecarTarget
    }

    if alreadyConnected {
        print("Sidecar: already connected")
    } else if let device = target {
        let sem = DispatchSemaphore(value: 0)
        let sel = NSSelectorFromString("connectToDevice:completion:")
        typealias Func = @convention(c) (NSObject, Selector, NSObject, @escaping (Error?) -> Void) -> Void
        let call = unsafeBitCast(manager.method(for: sel), to: Func.self)
        call(manager, sel, device) { error in
            if let error = error { print("Sidecar error: \(error)") }
            else { print("Sidecar: connected \(sidecarTarget)") }
            sem.signal()
        }
        sem.wait()
    } else {
        print("Sidecar: \(sidecarTarget) not available")
    }
} else {
    print("Sidecar: framework load failed")
}

// Duet: ensure app is running; Air Auto-Connect pref handles the link itself.
let open = Process()
open.launchPath = "/usr/bin/open"
open.arguments = ["-ga", "duet"]
try? open.run()
open.waitUntilExit()
