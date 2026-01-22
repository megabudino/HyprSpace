import AppKit
import Common
import PrivateApi

@MainActor
private var activeRefreshTask: Task<(), any Error>? = nil

@MainActor
func runRefreshSession(
    _ event: RefreshSessionEvent,
    optimisticallyPreLayoutWorkspaces: Bool = false,
) {
    activeRefreshTask?.cancel()
    activeRefreshTask = Task { @MainActor in
        try checkCancellation()
        try await runRefreshSessionBlocking(event, optimisticallyPreLayoutWorkspaces: optimisticallyPreLayoutWorkspaces)
    }
}

@MainActor
func runRefreshSessionBlocking(
    _ event: RefreshSessionEvent,
    layoutWorkspaces shouldLayoutWorkspaces: Bool = true,
    optimisticallyPreLayoutWorkspaces: Bool = false,
) async throws {
    let state = signposter.beginInterval(#function, "event: \(event) axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
    defer { signposter.endInterval(#function, state) }
    if !TrayMenuModel.shared.isEnabled { return }
    try await $refreshSessionEvent.withValue(event) {
        try await $_isStartup.withValue(event.isStartup) {
            let nativeFocused = try await getNativeFocusedWindow()
            if let nativeFocused { try await debugWindowsIfRecording(nativeFocused) }
            updateFocusCache(nativeFocused)

            if shouldLayoutWorkspaces && optimisticallyPreLayoutWorkspaces { try await layoutWorkspaces() }

            refreshModel()
            try await refresh()
            gcMonitors()

            updateTrayText()
            try await normalizeLayoutReason()
            if shouldLayoutWorkspaces { try await layoutWorkspaces() }
        }
    }
}

@MainActor
func runSession<T>(
    _ event: RefreshSessionEvent,
    _ token: RunSessionGuard,
    body: @MainActor () async throws -> T
) async throws -> T {
    let state = signposter.beginInterval(#function, "event: \(event) axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
    defer { signposter.endInterval(#function, state) }
    activeRefreshTask?.cancel() // Give priority to runSession
    activeRefreshTask = nil
    return try await $refreshSessionEvent.withValue(event) {
        try await $_isStartup.withValue(event.isStartup) {
            let nativeFocused = try await getNativeFocusedWindow()
            if let nativeFocused { try await debugWindowsIfRecording(nativeFocused) }
            updateFocusCache(nativeFocused)
            let focusBefore = focus.windowOrNil

            refreshModel()
            let result = try await body()
            refreshModel()

            let focusAfter = focus.windowOrNil

            updateTrayText()
            try await layoutWorkspaces()
            if focusBefore != focusAfter {
                focusAfter?.nativeFocus() // syncFocusToMacOs
            }
            runRefreshSession(event)
            return result
        }
    }
}

struct RunSessionGuard: Sendable {
    @MainActor
    static var isServerEnabled: RunSessionGuard? { TrayMenuModel.shared.isEnabled ? forceRun : nil }
    @MainActor
    static func isServerEnabled(orIsEnableCommand command: (any Command)?) -> RunSessionGuard? {
        command is EnableCommand ? .forceRun : .isServerEnabled
    }
    @MainActor
    static var checkServerIsEnabledOrDie: RunSessionGuard { .isServerEnabled ?? dieT("server is disabled") }
    static let forceRun = RunSessionGuard()
    private init() {}
}

@MainActor
func refreshModel() {
    Workspace.garbageCollectUnusedWorkspaces()
    checkOnFocusChangedCallbacks()
    normalizeContainers()
}

@MainActor
private func refresh() async throws {
    // Garbage collect terminated apps and windows before working with all windows
    let mapping = try await MacApp.refreshAllAndGetAliveWindowIds(frontmostAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    let aliveWindowIds = mapping.values.flatMap { $0 }

    for window in MacWindow.allWindows {
        if !aliveWindowIds.contains(window.windowId) {
            window.garbageCollect(skipClosedWindowsCache: false)
        }
    }
    for (app, windowIds) in mapping {
        for windowId in windowIds {
            try await MacWindow.getOrRegister(windowId: windowId, macApp: app)
        }
    }

    // Garbage collect workspaces after apps, because workspaces contain apps.
    Workspace.garbageCollectUnusedWorkspaces()
}

func refreshObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    let notif = notif as String
    if notif == kAXWindowCreatedNotification {
        print("⏱️ [DIAG] kAXWindowCreated received")
        
        // Check what role the ax element has - it might be the window itself!
        var rawRole: AnyObject?
        let roleResult = AXUIElementCopyAttributeValue(ax, kAXRoleAttribute as CFString, &rawRole)
        let role = rawRole as? String ?? "unknown"
        print("⏱️ [DIAG] ax element role: \(role) (result: \(roleResult.rawValue))")
        
        // Try to get window ID directly from ax - it might be the window
        var windowId = CGWindowID()
        let windowIdResult = _AXUIElementGetWindow(ax, &windowId)
        print("⏱️ [DIAG] Direct window ID from ax: \(windowId) (result: \(windowIdResult.rawValue))")
        
        if let token = axTaskLocalAppThreadToken,
           let screen = NSScreen.main,
           windowIdResult == .success,
           windowId != 0
        {
            let knownWindowIds = getKnownWindowIds(pid: token.pid)
            print("⏱️ [DIAG] Window \(windowId), known: \(knownWindowIds)")
            if !knownWindowIds.contains(UInt32(windowId)) {
                let skipSubroles: Set<String> = [
                    "AXDialog",
                    "AXFloatingWindow",
                    "AXSystemFloatingWindow",
                    "AXSheet",
                ]
                var rawSubrole: AnyObject?
                let subroleResult = AXUIElementCopyAttributeValue(ax, kAXSubroleAttribute as CFString, &rawSubrole)
                if subroleResult == .success,
                   let subrole = rawSubrole as? String,
                   skipSubroles.contains(subrole)
                {
                    print("⏱️ [DIAG] Skipping window \(windowId) with subrole: \(subrole)")
                } else {
                    // Try multiple approaches to hide immediately
                    
                    // Approach 1: Try kAXHiddenAttribute (may not work for windows)
                    let hiddenResult = AXUIElementSetAttributeValue(ax, kAXHiddenAttribute as CFString, kCFBooleanTrue)
                    print("⏱️ [DIAG] kAXHiddenAttribute result: \(hiddenResult.rawValue)")
                    
                    // Approach 2: Set size to 1x1 AND position offscreen
                    var tinySize = CGSize(width: 1, height: 1)
                    var offscreenPoint = CGPoint(x: screen.frame.width + 100, y: screen.frame.height + 100)
                    if let sizeValue = AXValueCreate(.cgSize, &tinySize),
                       let positionValue = AXValueCreate(.cgPoint, &offscreenPoint)
                    {
                        let sizeResult = AXUIElementSetAttributeValue(ax, kAXSizeAttribute as CFString, sizeValue)
                        let posResult = AXUIElementSetAttributeValue(ax, kAXPositionAttribute as CFString, positionValue)
                        print("⏱️ [DIAG] Hide window \(windowId): size=\(sizeResult.rawValue), pos=\(posResult.rawValue)")
                    }
                }
            } else {
                print("⏱️ [DIAG] Window \(windowId) already known")
            }
        }
    }
    Task { @MainActor in
        if !TrayMenuModel.shared.isEnabled { return }
        runRefreshSession(.ax(notif))
    }
}

// Thread-safe storage for known window IDs, accessible from per-app threads
// Synchronization handled manually via knownWindowIdsLock
private let knownWindowIdsLock = NSLock()
nonisolated(unsafe) private var knownWindowIdsByPid: [pid_t: Set<UInt32>] = [:]

func getKnownWindowIds(pid: pid_t) -> Set<UInt32> {
    knownWindowIdsLock.lock()
    defer { knownWindowIdsLock.unlock() }
    return knownWindowIdsByPid[pid] ?? []
}

func addKnownWindowId(pid: pid_t, windowId: UInt32) {
    knownWindowIdsLock.lock()
    defer { knownWindowIdsLock.unlock() }
    knownWindowIdsByPid[pid, default: []].insert(windowId)
}

func removeKnownWindowId(pid: pid_t, windowId: UInt32) {
    knownWindowIdsLock.lock()
    defer { knownWindowIdsLock.unlock() }
    knownWindowIdsByPid[pid]?.remove(windowId)
}

func removeAllKnownWindowIds(pid: pid_t) {
    knownWindowIdsLock.lock()
    defer { knownWindowIdsLock.unlock() }
    knownWindowIdsByPid.removeValue(forKey: pid)
}

enum OptimalHideCorner {
    case bottomLeftCorner, bottomRightCorner
}

@MainActor
private func layoutWorkspaces() async throws {
    if !TrayMenuModel.shared.isEnabled {
        for workspace in Workspace.all {
            workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).unhideFromCorner() } // todo as!
            try await workspace.layoutWorkspace() // Unhide tiling windows from corner
        }
        return
    }
    let monitors = monitors
    var monitorToOptimalHideCorner: [CGPoint: OptimalHideCorner] = [:]
    for monitor in monitors {
        let xOff = monitor.width * 0.1
        let yOff = monitor.height * 0.1
        // brc = bottomRightCorner
        let brc1 = monitor.rect.bottomRightCorner + CGPoint(x: 2, y: -yOff)
        let brc2 = monitor.rect.bottomRightCorner + CGPoint(x: -xOff, y: 2)
        let brc3 = monitor.rect.bottomRightCorner + CGPoint(x: 2, y: 2)

        // blc = bottomLeftCorner
        let blc1 = monitor.rect.bottomLeftCorner + CGPoint(x: -2, y: -yOff)
        let blc2 = monitor.rect.bottomLeftCorner + CGPoint(x: xOff, y: 2)
        let blc3 = monitor.rect.bottomLeftCorner + CGPoint(x: -2, y: 2)

        let corner: OptimalHideCorner =
            monitors.contains(where: { m in m.rect.contains(brc1) || m.rect.contains(brc2) || m.rect.contains(brc3) }) &&
            monitors.allSatisfy { m in !m.rect.contains(blc1) && !m.rect.contains(blc2) && !m.rect.contains(blc3) }
            ? .bottomLeftCorner
            : .bottomRightCorner
        monitorToOptimalHideCorner[monitor.rect.topLeftCorner] = corner
    }

    // to reduce flicker, first unhide visible workspaces, then hide invisible ones
    for monitor in monitors {
        let workspace = monitor.activeWorkspace
        workspace.allLeafWindowsRecursive.forEach { ($0 as! MacWindow).unhideFromCorner() } // todo as!
        try await workspace.layoutWorkspace()
    }
    for workspace in Workspace.all where !workspace.isVisible {
        let corner = monitorToOptimalHideCorner[workspace.workspaceMonitor.rect.topLeftCorner] ?? .bottomRightCorner
        for window in workspace.allLeafWindowsRecursive {
            try await (window as! MacWindow).hideInCorner(corner) // todo as!
        }
    }
}

@MainActor
private func normalizeContainers() {
    // Can't do it only for visible workspace because most of the commands support --window-id and --workspace flags
    for workspace in Workspace.all {
        workspace.normalizeContainers()
    }
}
