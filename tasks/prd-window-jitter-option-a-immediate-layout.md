# PRD: Window Jitter Fix - Option A (Immediate Layout)

## Introduction

Eliminate the visual jitter when new windows open by calculating and applying the target tiled position immediately during window registration, before the window becomes visible at macOS's default position. This approach sets the correct frame as early as possible in the window lifecycle, potentially preserving macOS Tahoe's native window opening animation if the frame is set before the animation begins.

## Goals

- Eliminate visible jitter when new tiling windows open
- Window appears directly at its correct tiled position
- Potentially preserve macOS Tahoe's native window opening animation
- Handle all window types correctly (tiling, floating, popup, dialog)
- Support multi-monitor setups
- Maintain performance with minimal additional AX API calls

## User Stories

### US-001: Extract layout calculation for single window
**Description:** As a developer, I need to calculate a window's target rect without running full tree layout so that I can position windows immediately on detection.

**Acceptance Criteria:**
- [ ] Create `calculateTargetRect(for window: Window) -> CGRect?` function
- [ ] Function computes correct position based on parent container, siblings, adaptive weights
- [ ] Function respects gaps and padding configuration
- [ ] Function handles all tiling layouts (tiles, accordion, dwindle)
- [ ] Function returns nil for non-tiling windows (popup, dialog, floating)
- [ ] Result matches what `layoutRecursive` would compute for the same window
- [ ] Typecheck passes (`./build-debug.sh`)

### US-002: Apply immediate frame on window registration
**Description:** As a user, I want new tiling windows to appear at their correct position immediately so I don't see them jump from the default macOS position.

**Acceptance Criteria:**
- [ ] In `MacWindow.getOrRegister`, after binding window to tree, call `calculateTargetRect`
- [ ] If target rect is available, call `setFrame` immediately before returning
- [ ] Frame is set before `tryOnWindowDetected` callbacks run
- [ ] Subsequent `layoutWorkspaces()` call produces identical positioning (idempotent)
- [ ] No visible jitter when opening new windows
- [ ] Typecheck passes (`./build-debug.sh`)

### US-003: Handle popup and dialog windows correctly
**Description:** As a user, I want popup and dialog windows to open at their natural macOS position without interference.

**Acceptance Criteria:**
- [ ] Popup windows (bound to `macosPopupWindowsContainer`) are not repositioned
- [ ] Dialog windows (bound to workspace directly) are not repositioned
- [ ] Only tiling windows (bound to `TilingContainer` or `rootTilingContainer`) get immediate layout
- [ ] Typecheck passes (`./build-debug.sh`)

### US-004: Handle floating windows correctly
**Description:** As a user, I want floating windows to appear at their natural position, respecting any `on-window-detected` callbacks.

**Acceptance Criteria:**
- [ ] Floating windows are not repositioned by immediate layout
- [ ] `on-window-detected` callbacks can still move floating windows as expected
- [ ] Typecheck passes (`./build-debug.sh`)

### US-005: Support multi-monitor configurations
**Description:** As a user with multiple monitors, I want new windows to appear correctly on the appropriate monitor.

**Acceptance Criteria:**
- [ ] `calculateTargetRect` uses correct monitor's rect based on target workspace
- [ ] Windows opening on non-focused monitors position correctly
- [ ] Gaps and padding respect per-monitor configuration if applicable
- [ ] Test with 2+ monitors (can use DeskPad or BetterDisplay 2)
- [ ] Typecheck passes (`./build-debug.sh`)

### US-006: Handle tree normalization edge cases
**Description:** As a developer, I need the immediate layout to work correctly even when the tree hasn't been fully normalized yet.

**Acceptance Criteria:**
- [ ] `calculateTargetRect` handles unnormalized tree states gracefully
- [ ] If tree state is ambiguous, function returns nil (falls back to normal layout)
- [ ] No crashes or incorrect positions due to tree state assumptions
- [ ] Typecheck passes (`./build-debug.sh`)

### US-007: Ensure layout idempotency
**Description:** As a developer, I need the immediate layout and subsequent full layout to produce identical results.

**Acceptance Criteria:**
- [ ] Add unit tests comparing `calculateTargetRect` output with `layoutRecursive` output
- [ ] Tests cover various container configurations (1 window, 2 windows, nested containers)
- [ ] Tests cover all layout modes (tiles, accordion, dwindle)
- [ ] Tests pass (`./run-tests.sh`)

## Functional Requirements

- FR-1: Create `calculateTargetRect(for:)` function that computes a window's tiled position
- FR-2: Call `calculateTargetRect` in `MacWindow.getOrRegister` after binding to tree
- FR-3: Apply computed frame via `setFrame` before returning from registration
- FR-4: Skip immediate layout for popup, dialog, and floating windows
- FR-5: Handle multi-monitor setups using target workspace's monitor rect
- FR-6: Return nil and skip immediate layout if tree state is ambiguous
- FR-7: Ensure `layoutWorkspaces()` produces identical positioning (idempotent behavior)

## Non-Goals

- No animation interpolation or custom animation system
- No changes to existing `layoutRecursive` algorithm
- No configuration options in this initial implementation
- No changes to workspace switching behavior
- No changes to floating window behavior

## Technical Considerations

- Must extract layout logic from `layoutRecursive.swift` without duplication
- Consider creating shared layout calculation utilities used by both paths
- `calculateTargetRect` must be efficient (called on every window creation)
- Must handle the case where parent container's rect isn't yet computed
- May need to compute parent rects recursively up the tree
- Thread safety: calculation happens on main actor, same as registration

### Key Files to Modify
- `Sources/AppBundle/tree/MacWindow.swift` - Add immediate layout call
- `Sources/AppBundle/layout/layoutRecursive.swift` - Extract calculation logic
- New file: `Sources/AppBundle/layout/calculateTargetRect.swift`

### Dependencies
- Requires understanding of `adaptiveWeight` system
- Requires understanding of gap/padding configuration
- Requires understanding of layout modes (tiles, accordion, dwindle)

## Success Metrics

- Zero visible jitter when opening new tiling windows
- No performance regression (window opening feels instant)
- Layout calculation matches full layout pass (no position drift)
- All existing tests pass
- Code is maintainable (no significant duplication of layout logic)

## Open Questions

- Can we set the frame early enough to preserve macOS Tahoe's window animation?
- Should we run a "mini normalization" before calculating the target rect?
- How do we handle the case where the window's siblings haven't been laid out yet?
- Should this be configurable via `~/.hyprspace.toml`?
