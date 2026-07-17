//
//  sidecar — a self-contained CLI to manage Sidecar (iPad-as-display) sessions.
//
//  Drives the private SidecarCore.framework directly (no UI automation, no
//  AppleScript). Connection state is read from the framework itself via
//  SidecarDisplayManager.connectedDevices, so `toggle`/`status` are reliable
//  without sniffing display names or shelling out to system_profiler.
//
//  Display arrangement (`arrange`, `list`, and the --arrange flags on
//  connect/toggle) is done through CoreGraphics' display-reconfiguration API,
//  which is display-type-agnostic: the target display is moved flush against
//  the built-in panel on the requested side. So `arrange`/`list` work on *any*
//  external display — an ordinary wired monitor (HDMI/USB-C/Thunderbolt) as
//  well as a Sidecar iPad. Only connect/disconnect/toggle are Sidecar-specific,
//  since SidecarCore is the only backend that can attach/detach a display.
//
//  Commands:
//    devices                 List reachable Sidecar-capable device names.
//    connected               List currently-connected Sidecar device names.
//    list                    List every attached external display (arrange targets),
//                            each tagged Wired or Sidecar.
//    status     <name>       Print connected|disconnected (exit 0 if connected, 8 if not).
//                            When connected, also prints the current arrangement.
//    connect    <name> [-wired] [--arrange=...] [--arrange-align=...] [--arrange-offset=...]
//    disconnect <name>
//    toggle     <name> [-wired] [--arrange=...] [--arrange-align=...] [--arrange-offset=...]
//    arrange    <name> --arrange=<left|top|right|bottom> [--arrange-align=...] [--arrange-offset=...]
//
//  A Sidecar device is always attached as an *extended* display, so "extend to"
//  == connect and "stop extending" == disconnect. (SidecarCore exposes no
//  mirror/extend switch; macOS mirroring is a separate, non-Sidecar API.)
//
//  Arrange flags:
//    --arrange=<left|top|right|bottom>   Place the Sidecar display on that side of
//                                        the main (built-in) screen, flush against it.
//    --arrange-align=<start|center|end>  Alignment along the perpendicular axis.
//                                        Default: center.
//    --arrange-offset=<±pixels>          Shift the aligned position. For left/right,
//                                        positive moves down; for top/bottom, positive
//                                        moves right. Default: 0.
//    On connect/toggle the display is arranged once it appears; with the standalone
//    `arrange` command the device must already be connected.
//
//  Exit codes:
//    0  success / device connected (status)
//    1  invalid input
//    2  no reachable Sidecar devices detected
//    3  named device / display not found
//    4  SidecarCore or CoreGraphics returned an error
//    8  device not connected (status only)
//

import Foundation
import AppKit

// MARK: - CLI parsing

enum Command: String {
    case devices
    case connected
    case list
    case status
    case connect
    case disconnect
    case toggle
    case arrange
}

enum Side: String {
    case left
    case right
    case top
    case bottom
}

enum Align: String {
    case start
    case center
    case end
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
      sidecar devices                       List reachable Sidecar device names.
      sidecar connected                     List currently-connected Sidecar device names.
      sidecar list                          List attached external displays, tagged by type.
      sidecar status     <name>             Print connected|disconnected (+ arrangement).
      sidecar connect    <name> [\(wiredFlag)] [arrange flags]   Connect (extend) to the device.
      sidecar disconnect <name>             Disconnect (stop extending).
      sidecar toggle     <name> [\(wiredFlag)] [arrange flags]   Toggle the connection.
      sidecar arrange    <name> --arrange=<side> [arrange flags] Reposition an attached display.

    `arrange` and `list` work on any external display (wired monitor or Sidecar);
    connect/disconnect/toggle are Sidecar-only. Names are matched case-insensitively
    (use `list`/`devices` to see them). Quote names with spaces.
    The optional \(wiredFlag) flag forces a wired Sidecar session (experimental).

    Arrange flags:
      --arrange=<left|top|right|bottom>   Side of the main screen to place the display.
      --arrange-align=<start|center|end>  Alignment along the perpendicular axis (default center).
      --arrange-offset=<±pixels>          Shift the aligned position (default 0). Positive moves
                                          down (left/right) or right (top/bottom).

    On connect/toggle the display is arranged once it appears; `arrange` requires it
    to be connected already.
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

let needsName = command == .status || command == .connect || command == .disconnect
    || command == .toggle || command == .arrange

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

// Parse the arrange flags out of everything after the command (+ name).
var arrangeSide: Side?
var arrangeAlign: Align = .center
var arrangeOffset = 0

func splitFlag(_ token: String) -> (key: String, inlineValue: String?) {
    guard let eq = token.firstIndex(of: "=") else { return (token, nil) }
    return (String(token[..<eq]), String(token[token.index(after: eq)...]))
}

let flagArgs = needsName ? Array(arguments.dropFirst(3)) : Array(arguments.dropFirst(2))
var flagIndex = 0
while flagIndex < flagArgs.count {
    let token = flagArgs[flagIndex]
    if token.lowercased() == wiredFlag {
        flagIndex += 1
        continue
    }

    let (key, inlineValue) = splitFlag(token)

    // The flag's value is either inline (--key=value) or the next token (--key value).
    func takeValue() -> String? {
        if let inlineValue { return inlineValue }
        if flagIndex + 1 < flagArgs.count {
            flagIndex += 1
            return flagArgs[flagIndex]
        }
        return nil
    }

    switch key.lowercased() {
    case "--arrange":
        guard let value = takeValue(), let side = Side(rawValue: value.lowercased()) else {
            fail("--arrange requires one of: left, top, right, bottom", 1)
        }
        arrangeSide = side
    case "--arrange-align":
        guard let value = takeValue(), let align = Align(rawValue: value.lowercased()) else {
            fail("--arrange-align requires one of: start, center, end", 1)
        }
        arrangeAlign = align
    case "--arrange-offset":
        guard let value = takeValue(), let pixels = Int(value) else {
            fail("--arrange-offset requires an integer number of pixels", 1)
        }
        arrangeOffset = pixels
    default:
        if key.hasPrefix("--") { fail("Unknown flag: \(key)", 1) }
    }
    flagIndex += 1
}

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

// MARK: - Display geometry (CoreGraphics)

/// The CGDirectDisplayIDs of all currently-active displays. Always a live query,
/// so it stays correct as displays appear/disappear within this process.
func activeDisplayIDs() -> [CGDirectDisplayID] {
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
    return Array(ids.prefix(Int(count)))
}

func screenDisplayID(_ screen: NSScreen) -> CGDirectDisplayID? {
    (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
        .map { CGDirectDisplayID($0.uint32Value) }
}

/// The display to arrange *against*: the built-in panel ("my main screen"),
/// or the OS main display on a deskbound Mac with no built-in.
func anchorDisplayID(excluding excluded: CGDirectDisplayID) -> CGDirectDisplayID {
    if let builtin = activeDisplayIDs().first(where: { CGDisplayIsBuiltin($0) != 0 && $0 != excluded }) {
        return builtin
    }
    return CGMainDisplayID()
}

/// Resolve an external display by its localized screen name (fresh at process
/// start), falling back to the sole non-built-in display. Works for any external
/// panel — a wired monitor as readily as a Sidecar iPad — since it only matches
/// on the name CoreGraphics/AppKit reports.
func resolveExternalDisplayID(named name: String) -> CGDirectDisplayID? {
    let lowered = name.lowercased()

    // Direct hit on the panel's own name — a wired monitor by its model, or a
    // Sidecar panel that macOS happened to label after the device.
    for screen in NSScreen.screens
    where screen.localizedName.lowercased().contains(lowered) {
        if let id = screenDisplayID(screen) { return id }
    }

    let externals = activeDisplayIDs().filter { CGDisplayIsBuiltin($0) == 0 }

    // A Sidecar device is named after the iPad (e.g. "Leto"), but its panel is
    // usually labelled "Sidecar Display (AirPlay)" — so the loop above misses it.
    // If the requested name is a connected Sidecar device, resolve to whichever
    // external panel classifies as Sidecar.
    let sidecarNames = connectedSidecarNames()
    if sidecarNames.contains(where: { $0.contains(lowered) || lowered.contains($0) }),
       let id = externals.first(where: { classifyDisplay($0, sidecarNames: sidecarNames) == .sidecar }) {
        return id
    }

    // Last resort: a lone external panel must be the one meant.
    return externals.count == 1 ? externals.first : nil
}

// MARK: - External display inventory

/// How an external display is attached. CoreGraphics exposes no "is this
/// Sidecar/AirPlay" flag, so the kind is inferred by cross-referencing the
/// display's name against SidecarCore's own connected-device list.
enum DisplayKind {
    case wired
    case sidecar

    /// Nerd Font-tagged label used by the `list` command.
    var tag: String {
        switch self {
        case .wired:   return "󰍹  Wired"
        case .sidecar: return "󰦉  Sidecar"
        }
    }
}

/// The localized name of a display, via its backing NSScreen. Falls back to a
/// synthetic label if no NSScreen matches (shouldn't happen for active displays).
func displayName(_ id: CGDirectDisplayID) -> String {
    for screen in NSScreen.screens where screenDisplayID(screen) == id {
        return screen.localizedName
    }
    return "Display \(id)"
}

/// Lowercased names of the Sidecar devices macOS currently reports as connected —
/// the reference set for telling a Sidecar panel apart from a plain wired display.
func connectedSidecarNames() -> Set<String> {
    Set(deviceList("connectedDevices").map { deviceName($0).lowercased() }.filter { !$0.isEmpty })
}

/// Classify an external display. Two Sidecar signals, either sufficient:
///   • macOS labels the panel itself "Sidecar Display (AirPlay)" — the strongest,
///     locale-stable marker (a wired monitor reports its model name instead);
///   • on setups that name the panel after the device, it matches a connected
///     Sidecar device name from SidecarCore (e.g. "Leto").
func classifyDisplay(_ id: CGDirectDisplayID, sidecarNames: Set<String>) -> DisplayKind {
    let name = displayName(id).lowercased()
    let isSidecar = name.contains("sidecar") || sidecarNames.contains(where: { name.contains($0) })
    return isSidecar ? .sidecar : .wired
}

/// The new display ID that appears after connecting (vs. a pre-connect snapshot),
/// preferring a non-built-in one. Spins the run loop so the window server settles.
func waitForNewDisplay(notIn known: [CGDirectDisplayID], timeout: TimeInterval = 6) -> CGDirectDisplayID? {
    let knownSet = Set(known)
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        let fresh = activeDisplayIDs().filter { !knownSet.contains($0) }
        if let id = fresh.first(where: { CGDisplayIsBuiltin($0) == 0 }) ?? fresh.first {
            return id
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
    } while Date() < deadline
    return nil
}

/// The aligned origin coordinate along the axis perpendicular to the chosen side.
func perpendicularOrigin(
    anchorStart: CGFloat,
    anchorExtent: CGFloat,
    movedExtent: CGFloat,
    align: Align,
    offset: Int
) -> CGFloat {
    let base: CGFloat
    switch align {
    case .start:  base = anchorStart
    case .center: base = anchorStart + (anchorExtent - movedExtent) / 2
    case .end:    base = anchorStart + (anchorExtent - movedExtent)
    }
    return base + CGFloat(offset)
}

/// Move `sidecarID` flush against the anchor on `side`, then commit the change.
func arrangeDisplay(
    _ sidecarID: CGDirectDisplayID,
    side: Side,
    align: Align,
    offset: Int,
    label: String
) -> Never {
    let anchorID = anchorDisplayID(excluding: sidecarID)
    guard anchorID != sidecarID else {
        fail("The display for \"\(label)\" is the main display — nothing to arrange it against.", 1)
    }

    let anchor = CGDisplayBounds(anchorID)
    let moved = CGDisplayBounds(sidecarID)

    // Global display space: top-left origin, y increases downward — the same
    // space CGConfigureDisplayOrigin expects, so coordinates pass through directly.
    var x = moved.origin.x
    var y = moved.origin.y

    switch side {
    case .left:
        x = anchor.minX - moved.width
        y = perpendicularOrigin(anchorStart: anchor.minY, anchorExtent: anchor.height,
                                movedExtent: moved.height, align: align, offset: offset)
    case .right:
        x = anchor.maxX
        y = perpendicularOrigin(anchorStart: anchor.minY, anchorExtent: anchor.height,
                                movedExtent: moved.height, align: align, offset: offset)
    case .top:
        y = anchor.minY - moved.height
        x = perpendicularOrigin(anchorStart: anchor.minX, anchorExtent: anchor.width,
                                movedExtent: moved.width, align: align, offset: offset)
    case .bottom:
        y = anchor.maxY
        x = perpendicularOrigin(anchorStart: anchor.minX, anchorExtent: anchor.width,
                                movedExtent: moved.width, align: align, offset: offset)
    }

    var config: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&config) == .success, let config else {
        fail("Failed to begin display reconfiguration.", 4)
    }
    let originStatus = CGConfigureDisplayOrigin(config, sidecarID, Int32(x.rounded()), Int32(y.rounded()))
    guard originStatus == .success else {
        _ = CGCancelDisplayConfiguration(config)
        fail("Couldn't set the display origin (CGError \(originStatus.rawValue)).", 4)
    }
    guard CGCompleteDisplayConfiguration(config, .permanently) == .success else {
        fail("Couldn't apply the display configuration.", 4)
    }

    print("arranged \(label) → \(side.rawValue) (align: \(align.rawValue), offset: \(offset)px)")
    exit(0)
}

/// Human-readable description of where `sidecarID` currently sits relative to the
/// main screen. The reported offset is the signed distance from the centered
/// position along the perpendicular axis — i.e. the `--arrange-offset` you'd pass
/// (with the default `--arrange-align=center`) to reproduce the layout.
func describeArrangement(_ sidecarID: CGDirectDisplayID) -> String {
    let anchorID = anchorDisplayID(excluding: sidecarID)
    guard anchorID != sidecarID else { return "is the main screen" }

    let a = CGDisplayBounds(anchorID)
    let s = CGDisplayBounds(sidecarID)
    let tolerance: CGFloat = 1

    let side: Side
    let offset: Int
    if s.minX >= a.maxX - tolerance {
        side = .right
        offset = Int((s.minY - (a.minY + (a.height - s.height) / 2)).rounded())
    } else if s.maxX <= a.minX + tolerance {
        side = .left
        offset = Int((s.minY - (a.minY + (a.height - s.height) / 2)).rounded())
    } else if s.minY >= a.maxY - tolerance {
        side = .bottom
        offset = Int((s.minX - (a.minX + (a.width - s.width) / 2)).rounded())
    } else if s.maxY <= a.minY + tolerance {
        side = .top
        offset = Int((s.minX - (a.minX + (a.width - s.width) / 2)).rounded())
    } else {
        return "overlapping the main screen"
    }

    let position = offset == 0 ? "centered" : "offset \(offset > 0 ? "+" : "")\(offset)px from center"
    return "\(side.rawValue) of main screen, \(position)"
}

// Snapshot displays before any connect so we can spot the Sidecar one afterward.
let preConnectDisplays = activeDisplayIDs()

/// After a successful connect, place the freshly-appeared display if asked.
let arrangeAfterConnect: () -> Void = {
    guard let side = arrangeSide else { return }
    guard let sidecarID = waitForNewDisplay(notIn: preConnectDisplays) else {
        fail("Connected, but no new display appeared in time to arrange it.", 4)
    }
    arrangeDisplay(sidecarID, side: side, align: arrangeAlign, offset: arrangeOffset, label: targetName)
}

// MARK: - Connect / disconnect

func runManagerAction(
    _ work: (_ completion: @escaping (NSError?) -> Void) -> Void,
    success: String,
    then: (() -> Void)? = nil
) -> Never {
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
    then?() // may itself exit (e.g. arrange)
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
        }, success: "connected", then: arrangeAfterConnect)
    }
    runManagerAction({ completion in
        let block: @convention(block) (NSError?) -> Void = { completion($0) }
        _ = manager.perform(Selector(("connectToDevice:completion:")), with: device, with: block)
    }, success: "connected", then: arrangeAfterConnect)
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

case .list:
    // Every attached external display is an arrange target. Tag each by how it's
    // attached, resolving Sidecar-ness once against the connected-device list.
    let sidecarNames = connectedSidecarNames()
    let externals = activeDisplayIDs().filter { CGDisplayIsBuiltin($0) == 0 }
    let rows = externals.map {
        (name: displayName($0), tag: classifyDisplay($0, sidecarNames: sidecarNames).tag)
    }
    // Left-align names in a column so the type tags line up (names are ASCII).
    let width = rows.map { $0.name.count }.max() ?? 0
    rows.forEach {
        let padded = $0.name.padding(toLength: max(width, $0.name.count), withPad: " ", startingAt: 0)
        print("\(padded)   \($0.tag)")
    }
    exit(0)

case .status:
    let isConnected = deviceList("connectedDevices").contains(where: matches)
    print(isConnected ? "connected" : "disconnected")
    if isConnected, let sidecarID = resolveExternalDisplayID(named: targetName) {
        print("arrangement: \(describeArrangement(sidecarID))")
    }
    exit(isConnected ? 0 : 8)

case .arrange:
    guard let side = arrangeSide else {
        fail("arrange requires --arrange=<left|top|right|bottom>", 1)
    }
    guard let sidecarID = resolveExternalDisplayID(named: targetName) else {
        fail("Couldn't find an attached display for \"\(targetName)\".", 3)
    }
    arrangeDisplay(sidecarID, side: side, align: arrangeAlign, offset: arrangeOffset, label: targetName)

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
            print("connected") // already connected
            // Honor --arrange even when already connected: the display is already
            // present, so resolve it by name rather than waiting for a new one.
            if let side = arrangeSide {
                guard let sidecarID = resolveExternalDisplayID(named: targetName) else {
                    fail("Connected, but couldn't find \"\(targetName)\"'s display to arrange.", 3)
                }
                arrangeDisplay(sidecarID, side: side, align: arrangeAlign, offset: arrangeOffset, label: targetName)
            }
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
