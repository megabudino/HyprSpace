# PRD: Window Jitter Fix - Early Hide

## Introduction

Eliminate the visual jitter when new windows open by hiding them offscreen **immediately in the AX observer callback**, before any async work begins. This approach acts at the earliest possible point in the window lifecycle, guaranteeing the window is never visible at macOS's default position.

## Background

Previous attempts to hide windows during `MacWindow.getOrRegister` failed because there's an async gap between the notification arriving and the hide call executing. Diagnostic testing confirmed the window becomes visible during this gap. The solution is to act **synchronously** in `refreshObs` before dispatching any async work.

## Goals

- Eliminate visible jitter when new tiling windows open
- Act synchronously in observer callback before async dispatch
- Handle all window types correctly (tiling, floating, popup, dialog)
- Support multi-monitor setups
- Maintain performance (< 10ms added latency)

## User Stories

### US-001: Create synchronous window discovery helper
**Description:** As a developer, I need to synchronously get all windows from an app's AXUIElement so I can identify newly created windows in the observer callback.

**Acceptance Criteria:**
- [ ] Create function `getWindowIdsSync(from appElement: AXUIElement) -> [UInt32]`
- [ ] Uses `AXUIElementCopyAttributeValue` to get `kAXWindowsAttribute`
- [ ] Uses `_AXUIElementGetWindow` to get window ID for each window element
- [ ] Function is synchronous (no async/await)
- [ ] Add to `Sources/AppBundle/util/accessibility.swift`
- [ ] Typecheck passes (`./build-debug.sh`)

### US-002: Track known window IDs per app
**Description:** As a developer, I need to track which windows we've already seen so I can identify new ones when a creation notification arrives.

**Acceptance Criteria:**
- [ ] Add `knownWindowIds: Set<UInt32>` property to `MacApp`
- [ ] Update set when windows are registered in `MacWindow.getOrRegister`
- [ ] Update set when windows are garbage collected
- [ ] Thread-safe access (observer runs on per-app thread)
- [ ] Typecheck passes (`./build-debug.sh`)

### US-003: Hide new window immediately in observer
**Description:** As a user, I want new windows to be hidden before I can see them at their default macOS position.

**Acceptance Criteria:**
- [ ] In `refreshObs`, when `kAXWindowCreatedNotification` received:
  - Query app's current windows using `getWindowIdsSync`
  - Compare with `knownWindowIds` to find new window(s)
  - For each new window, set position offscreen immediately
- [ ] This happens BEFORE `Task { @MainActor in ... }` dispatch
- [ ] Use synchronous `AXUIElementSetAttributeValue` for position
- [ ] Hide to bottom-right corner of primary monitor (simple first pass)
- [ ] Typecheck passes (`./build-debug.sh`)

### US-004: Verify layout correctly positions hidden windows
**Description:** As a user, I want hidden windows to appear at their correct tiled position after layout runs.

**Acceptance Criteria:**
- [ ] Normal `layoutWorkspaces()` flow positions windows correctly
- [ ] Windows that were hidden offscreen now appear at tiled position
- [ ] No additional code needed in layout path
- [ ] Manually test: open new tiling window, confirm no jitter and correct final position
- [ ] Typecheck passes (`./build-debug.sh`)

### US-005: Handle popup and dialog windows
**Description:** As a user, I want popup and dialog windows to appear at their natural macOS position.

**Acceptance Criteria:**
- [ ] Detect window type synchronously using `kAXSubroleAttribute`
- [ ] Skip hiding for windows with subrole `AXDialog`, `AXFloatingWindow`, `AXSystemFloatingWindow`
- [ ] If detection is unreliable, hide all and let layout unhide non-tiling windows quickly
- [ ] Typecheck passes (`./build-debug.sh`)

### US-006: Support multi-monitor corner selection
**Description:** As a user with multiple monitors, I want windows hidden in a corner that doesn't overlap other monitors.

**Acceptance Criteria:**
- [ ] Determine target monitor (use primary monitor or focused workspace's monitor)
- [ ] Compute optimal hide corner using existing `computeMonitorToOptimalHideCorner` logic
- [ ] Hide window in computed corner
- [ ] Test with 2+ monitors
- [ ] Typecheck passes (`./build-debug.sh`)

### US-007: Remove diagnostic code
**Description:** As a developer, I need to clean up the diagnostic print statements.

**Acceptance Criteria:**
- [ ] Remove `print("⏱️ [DIAG]...")` statements from `refresh.swift`
- [ ] Remove `print("⏱️ [DIAG]...")` statements from `MacWindow.swift`
- [ ] Typecheck passes (`./build-debug.sh`)
- [ ] Tests pass (`./run-tests.sh`)

## Functional Requirements

- FR-1: Query app windows synchronously from AXUIElement
- FR-2: Track known window IDs per app
- FR-3: Identify new windows by comparing current vs known
- FR-4: Hide new windows offscreen immediately in observer callback (before async dispatch)
- FR-5: Skip hiding for popup/dialog windows (best effort)
- FR-6: Use optimal hide corner for multi-monitor setups
- FR-7: Rely on existing layout to position windows correctly

## Non-Goals

- No custom animation (windows appear instantly at tiled position)
- No preservation of macOS Tahoe window opening animation
- No configuration options
- No changes to layoutRecursive algorithm

## Technical Considerations

### Synchronous AX Calls
- Observer callback runs on per-app thread, can make sync AX calls
- `AXUIElementCopyAttributeValue` and `AXUIElementSetAttributeValue` are synchronous
- Must not block too long (affects app responsiveness)

### Thread Safety
- `knownWindowIds` accessed from per-app thread (observer) and main actor
- May need synchronization or careful access patterns
- Consider using the app's existing thread model

### Key Files to Modify
- `Sources/AppBundle/layout/refresh.swift` - Add early hide in `refreshObs`
- `Sources/AppBundle/tree/MacApp.swift` - Add `knownWindowIds` tracking
- `Sources/AppBundle/util/accessibility.swift` - Add `getWindowIdsSync` helper

## Success Metrics

- Zero visible jitter when opening new tiling windows
- Popup/dialog windows appear at natural positions
- No performance regression
- All existing tests pass

## Open Questions

- Is synchronous window type detection reliable enough?
- Should `knownWindowIds` be per-app or global?
- What if the new window ID isn't in the windows list yet when we query?
