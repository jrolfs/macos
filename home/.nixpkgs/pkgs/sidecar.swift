//
//  sidecar — a self-contained CLI to manage Sidecar (iPad-as-display) sessions.
//
//  Drives the private SidecarCore.framework directly (no UI automation, no
//  AppleScript). Connection state is read from the framework itself via
//  SidecarDisplayManager.connectedDevices, so `toggle`/`status` are reliable
//  without sniffing display names or shelling out to system_profiler.
//
//  Commands:
//    devices                 List reachable Sidecar-capable device names.
//    connected               List currently-connected device names.
//    status     <name>       Print connected|disconnected (exit 0 if connected, 8 if not).
//    connect    <name> [-wired]
//    disconnect <name>
//    toggle     <name> [-wired]   Disconnect if connected, else connect.
//
//  A Sidecar device is always attached as an *extended* display, so "extend to"
//  == connect and "stop extending" == disconnect. (SidecarCore exposes no
//  mirror/extend switch; macOS mirroring is a separate, non-Sidecar API.)
//
//  Exit codes:
//    0  success / device connected (status)
//    1  invalid input
//    2  no reachable Sidecar devices detected
//    3  named device not found
//    4  SidecarCore returned an error
//    8  device not connected (status only)
//

import Foundation

// MARK: - CLI parsing

enum Command: String {
    case devices
    case connected
    case status
    case connect
    case disconnect
    case toggle
}

let wiredFlag = "-wired"

func fail(_ message: String, _ code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

func printHelp() {
    print("""
    sidecar — manage Sidecar (iPad-as-display) sessions via SidecarCore.

    Usage:
      sidecar devices                       List reachable device names.
      sidecar connected                     List currently-connected device names.
      sidecar status     <name>             Print connected|disconnected.
      sidecar connect    <name> [\(wiredFlag)]    Connect (extend) to the device.
      sidecar disconnect <name>             Disconnect (stop extending).
      sidecar toggle     <name> [\(wiredFlag)]    Toggle the connection.

    Device names are matched case-insensitively. Quote names with spaces.
    The optional \(wiredFlag) flag forces a wired Sidecar session (experimental).
    """)
}

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    printHelp()
    exit(1)
}

guard let command = Command(rawValue: arguments[1].lowercased()) else {
    fail("Invalid command: \(arguments[1])", 1)
}

let needsName = command == .status || command == .connect || command == .disconnect || command == .toggle

let targetName: String
if needsName {
    guard arguments.count >= 3 else { fail("\(command.rawValue) requires a device name.", 1) }
    targetName = arguments[2]
} else {
    targetName = ""
}

let wantsWired: Bool = {
    guard command == .connect || command == .toggle else { return false }
    return arguments.dropFirst(3).contains { $0.lowercased() == wiredFlag }
}()

// MARK: - SidecarCore bridge

guard dlopen("/System/Library/PrivateFrameworks/SidecarCore.framework/SidecarCore", RTLD_LAZY) != nil else {
    fail("Failed to load SidecarCore.framework", 4)
}

guard let managerClass = NSClassFromString("SidecarDisplayManager") as? NSObject.Type else {
    fail("SidecarDisplayManager class not found (private API changed?)", 4)
}

guard let manager = managerClass.perform(Selector(("sharedManager")))?.takeUnretainedValue() as? NSObject else {
    fail("Failed to obtain SidecarDisplayManager.sharedManager", 4)
}

/// Returns the device objects from a manager selector (`devices`, `connectedDevices`, ...).
func deviceList(_ selector: String) -> [NSObject] {
    (manager.perform(Selector((selector)))?.takeUnretainedValue() as? [NSObject]) ?? []
}

func deviceName(_ device: NSObject) -> String {
    (device.perform(Selector(("name")))?.takeUnretainedValue() as? String) ?? ""
}

func matches(_ device: NSObject) -> Bool {
    deviceName(device).lowercased() == targetName.lowercased()
}

// MARK: - Connect / disconnect

func runManagerAction(_ work: (_ completion: @escaping (NSError?) -> Void) -> Void, success: String) -> Never {
    let group = DispatchGroup()
    group.enter()
    var resultError: NSError?
    work { error in
        resultError = error
        group.leave()
    }
    group.wait()
    if let error = resultError {
        fail("SidecarCore error: \(error.localizedDescription)", 4)
    }
    print(success)
    exit(0)
}

func connect(_ device: NSObject) -> Never {
    if wantsWired {
        guard let configClass = NSClassFromString("SidecarDisplayConfig") as? NSObject.Type else {
            fail("SidecarDisplayConfig class not found", 4)
        }
        let config = configClass.init()
        let setTransport = Selector(("setTransport:"))
        let setTransportIMP = config.method(for: setTransport)
        let setTransportFn = unsafeBitCast(setTransportIMP, to: (@convention(c) (Any?, Selector, Int64) -> Void).self)
        setTransportFn(config, setTransport, 2) // 2 == wired

        let connectSel = Selector(("connectToDevice:withConfig:completion:"))
        let connectIMP = manager.method(for: connectSel)
        let connectFn = unsafeBitCast(connectIMP, to: (@convention(c) (Any?, Selector, Any?, Any?, Any?) -> Void).self)
        runManagerAction({ completion in
            let block: @convention(block) (NSError?) -> Void = { completion($0) }
            connectFn(manager, connectSel, device, config, block)
        }, success: "connected")
    }
    runManagerAction({ completion in
        let block: @convention(block) (NSError?) -> Void = { completion($0) }
        _ = manager.perform(Selector(("connectToDevice:completion:")), with: device, with: block)
    }, success: "connected")
}

func disconnect(_ device: NSObject) -> Never {
    runManagerAction({ completion in
        let block: @convention(block) (NSError?) -> Void = { completion($0) }
        _ = manager.perform(Selector(("disconnectFromDevice:completion:")), with: device, with: block)
    }, success: "disconnected")
}

// MARK: - Dispatch

switch command {
case .devices:
    deviceList("devices").map(deviceName).forEach { print($0) }
    exit(0)

case .connected:
    deviceList("connectedDevices").map(deviceName).forEach { print($0) }
    exit(0)

case .status:
    let isConnected = deviceList("connectedDevices").contains(where: matches)
    print(isConnected ? "connected" : "disconnected")
    exit(isConnected ? 0 : 8)

case .connect, .disconnect, .toggle:
    let connected = deviceList("connectedDevices")
    let reachable = deviceList("devices")

    let isConnected = connected.contains(where: matches)

    // For disconnect we need the live connected object; for connect we need a
    // reachable one. Search the union (connected first) so each path finds it.
    let pool = connected + reachable
    let target = pool.first(where: matches)

    switch command {
    case .disconnect:
        guard isConnected, let target else {
            print("disconnected") // already not connected — desired end state
            exit(0)
        }
        disconnect(target)

    case .connect:
        if isConnected {
            print("connected") // already connected — desired end state
            exit(0)
        }
        guard !reachable.isEmpty else { fail("No reachable Sidecar devices detected.", 2) }
        guard let target else { fail("\(targetName) is not a reachable Sidecar device.", 3) }
        connect(target)

    case .toggle:
        if isConnected, let target {
            disconnect(target)
        }
        guard !reachable.isEmpty else { fail("No reachable Sidecar devices detected.", 2) }
        guard let target else { fail("\(targetName) is not a reachable Sidecar device.", 3) }
        connect(target)

    default:
        fatalError("unreachable")
    }
}
