#!/usr/bin/env swift

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Connect Displays
// @raycast.mode silent

// Optional parameters:
// @raycast.icon 🖥
// @raycast.packageName Display

import Foundation

func name(_ device: NSObject) -> String {
    device.perform(NSSelectorFromString("name"))?.takeUnretainedValue() as? String ?? "?"
}

if let bundle = Bundle(path: "/System/Library/PrivateFrameworks/SidecarCore.framework"), bundle.load(),
   let managerClass = NSClassFromString("SidecarDisplayManager") as? NSObject.Type,
   let manager = managerClass.perform(NSSelectorFromString("sharedManager"))?.takeUnretainedValue() as? NSObject {

    let devices = manager.perform(NSSelectorFromString("devices"))?.takeUnretainedValue() as? [NSObject] ?? []
    let connected = manager.perform(NSSelectorFromString("connectedDevices"))?.takeUnretainedValue() as? [NSObject] ?? []

    if let device = connected.first {
        print("Sidecar: already connected to \(name(device))")
    } else if devices.isEmpty {
        print("Sidecar: no devices available")
    } else {
        let sel = NSSelectorFromString("connectToDevice:completion:")
        typealias Func = @convention(c) (NSObject, Selector, NSObject, @escaping (Error?) -> Void) -> Void
        let call = unsafeBitCast(manager.method(for: sel), to: Func.self)
        // Several iPads may be listed but only some reachable; try each until one connects.
        for device in devices {
            let sem = DispatchSemaphore(value: 0)
            var failure: Error?
            call(manager, sel, device) { error in
                failure = error
                sem.signal()
            }
            sem.wait()
            if let error = failure {
                print("Sidecar: \(name(device)) failed: \(error)")
            } else {
                print("Sidecar: connected \(name(device))")
                break
            }
        }
    }
} else {
    print("Sidecar: framework load failed")
}
