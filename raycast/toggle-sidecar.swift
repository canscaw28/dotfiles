#!/usr/bin/env swift

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Toggle Sidecar
// @raycast.mode silent

// Optional parameters:
// @raycast.icon 🖥
// @raycast.packageName Display

import Foundation

guard let bundle = Bundle(path: "/System/Library/PrivateFrameworks/SidecarCore.framework"),
      bundle.load() else {
    print("Failed to load SidecarCore")
    exit(1)
}

guard let managerClass = NSClassFromString("SidecarDisplayManager") as? NSObject.Type,
      let manager = managerClass.perform(NSSelectorFromString("sharedManager"))?.takeUnretainedValue() as? NSObject else {
    print("Failed to get SidecarDisplayManager")
    exit(1)
}

let devices = manager.perform(NSSelectorFromString("devices"))?.takeUnretainedValue() as? [NSObject] ?? []
let connected = manager.perform(NSSelectorFromString("connectedDevices"))?.takeUnretainedValue() as? [NSObject] ?? []

guard let device = devices.first else {
    print("No iPad found")
    exit(1)
}

let name = device.perform(NSSelectorFromString("name"))?.takeUnretainedValue() as? String ?? "iPad"

let isConnected = connected.contains(where: {
    ($0.perform(NSSelectorFromString("name"))?.takeUnretainedValue() as? String) == name
})

let sem = DispatchSemaphore(value: 0)

if isConnected {
    let sel = NSSelectorFromString("disconnectFromDevice:completion:")
    typealias Func = @convention(c) (NSObject, Selector, NSObject, @escaping (Error?) -> Void) -> Void
    let call = unsafeBitCast(manager.method(for: sel), to: Func.self)
    call(manager, sel, device) { error in
        if let error = error { print("Error: \(error)") }
        else { print("Disconnected \(name)") }
        sem.signal()
    }
} else {
    let sel = NSSelectorFromString("connectToDevice:completion:")
    typealias Func = @convention(c) (NSObject, Selector, NSObject, @escaping (Error?) -> Void) -> Void
    let call = unsafeBitCast(manager.method(for: sel), to: Func.self)
    call(manager, sel, device) { error in
        if let error = error { print("Error: \(error)") }
        else { print("Connected \(name)") }
        sem.signal()
    }
}

sem.wait()
