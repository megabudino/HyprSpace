# PRD: Window Jitter Fix - Option B (Hide-then-Reveal)

## Introduction

Eliminate the visual jitter when new windows open by immediately hiding newly detected tiling windows offscreen (in a monitor corner), then revealing them at the correct position during the normal layout pass. This approach reuses the existing `hideInCorner`/`unhideFromCorner` pattern already used for workspace switching, minimizing new code and maintaining consistency with existing behavior.

## Goals

- Eliminate visible jitter when new tiling windows open
- Reuse existing `hideInCorner`/`unhideFromCorner` infrastructure
- Minimize code changes and maintain architectural consistency
- Handle all window types correctly (tiling, floating, popup, dialog)
- Support multi-monitor setups with optimal corner selection
- Maintain performance with minimal additional AX API calls

## User Stories

### US-001: Extract optimal corner calculation helper
**Description:** As a developer, I need a reusable function to compute the optimal hide corner for each monitor so I don't duplicate the multi-monitor corner logic.

**Acceptance Criteria:**
- [ ] Extract `computeMonitorToOptimalHideCorner(monitors:) -> [CGPoint: OptimalHideCorner]` from `layoutWorkspaces()`
- [ ] Function is pure and reusable from multiple call sites
- [ ] `layoutWorkspaces()` uses the extracted helper (no behavior change)
- [ ] Typecheck passes (`./build-debug.sh`)
- [ ] Existing tests pass (`./run-tests.sh`)

### US-002: Hide new tiling windows immediately on registration
**Description:** As a user, I want new tiling windows to be hidden offscreen immediately so I don't see them at the default macOS position.

**Acceptance Criteria:**
- [ ] In `MacWindow.getOrRegister`, after binding window to tree, check if window is tiling
- [ ] If tiling and workspace is visible, call `hideInCorner()` immediately
- [ ] Use optimal corner based on monitor configuration
- [ ] Window is hidden before `tryOnWindowDetected` callbacks run
- [ ] Typecheck passes (`./build-debug.sh`)

### US-003: Reveal windows at correct position during layout
**Description:** As a user, I want hidden windows to appear at their correct tiled position when layout runs.

**Acceptance Criteria:**
- [ ] Existing `layoutWorkspaces()` flow handles unhiding automatically
- [ ] `unhideFromCorner()` is called for visible workspace windows (already exists)
- [ ] `layoutRecursive` sets correct frame, overwriting the hidden position
- [ ] No additional code needed in layout path
- [ ] Typecheck passes (`./build-debug.sh`)

### US-004: Handle popup and dialog windows correctly
**Description:** As a user, I want popup and dialog windows to open at their natural macOS position without being hidden.

**Acceptance Criteria:**
- [ ] Popup windows (bound to `macosPopupWindowsContainer`) are not hidden
- [ ] Dialog windows (bound to workspace directly) are not hidden
- [ ] Only tiling windows (bound to `TilingContainer` or `rootTilingContainer`) are hidden
- [ ] Typecheck passes (`./build-debug.sh`)

### US-005: Handle floating windows correctly
**Description:** As a user, I want floating windows to appear at their natural position without being hidden.

**Acceptance Criteria:**
- [ ] Floating windows are not hidden on registration
- [ ] `on-window-detected` callbacks can position floating windows as expected
- [ ] Typecheck passes (`./build-debug.sh`)

### US-006: Support multi-monitor configurations
**Description:** As a user with multiple monitors, I want new windows to be hidden in the optimal corner that doesn't overlap with other monitors.

**Acceptance Criteria:**
- [ ] Use `computeMonitorToOptimalHideCorner` to select corner
- [ ] Windows hidden in bottom-left if bottom-right overlaps another monitor
- [ ] Windows hidden in bottom-right otherwise (default)
- [ ] Test with 2+ monitors (can use DeskPad or BetterDisplay 2)
- [ ] Typecheck passes (`./build-debug.sh`)

### US-007: Handle windows on invisible workspaces
**Description:** As a developer, I need to avoid double-hiding windows that are already on invisible workspaces.

**Acceptance Criteria:**
- [ ] Only hide windows on visible workspaces during registration
- [ ] Windows on invisible workspaces are handled by existing `layoutWorkspaces()` hide logic
- [ ] No redundant `hideInCorner` calls
- [ ] Typecheck passes (`./build-debug.sh`)

### US-008: Handle rapid window creation
**Description:** As a user opening multiple windows quickly, I want all of them to be handled correctly without race conditions.

**Acceptance Criteria:**
- [ ] Multiple windows created in quick succession are all hidden correctly
- [ ] No race between hide and layout operations
- [ ] Final positions are all correct after layout settles
- [ ] Typecheck passes (`./build-debug.sh`)

## Functional Requirements

- FR-1: Extract `computeMonitorToOptimalHideCorner(monitors:)` helper function
- FR-2: Call `hideInCorner()` in `MacWindow.getOrRegister` for tiling windows on visible workspaces
- FR-3: Use optimal corner selection to avoid multi-monitor overlap issues
- FR-4: Skip hiding for popup, dialog, and floating windows
- FR-5: Skip hiding for windows on invisible workspaces (already handled)
- FR-6: Rely on existing `layoutWorkspaces()` to reveal and position windows correctly

## Non-Goals

- No custom animation system
- No changes to `layoutRecursive` algorithm
- No changes to existing `hideInCorner`/`unhideFromCorner` behavior
- No configuration options in this initial implementation
- No preservation of macOS Tahoe window opening animation

## Technical Considerations

- Reuses existing battle-tested `hideInCorner`/`unhideFromCorner` pattern
- Minimal code changes (~30-50 lines)
- Two AX calls per window: hide (position) + layout (position + size)
- `hideInCorner` may read window rect/size (additional AX calls)
- Thread safety: all operations on main actor

### Key Files to Modify
- `Sources/AppBundle/layout/refresh.swift` - Extract corner helper
- `Sources/AppBundle/tree/MacWindow.swift` - Add hide call in `getOrRegister`

### Risks
- Some apps may behave oddly when moved offscreen briefly (rare)
- Brief moment where window exists offscreen (not visible to user)
- Does not preserve macOS Tahoe's native window animation

## Success Metrics

- Zero visible jitter when opening new tiling windows
- No performance regression (window opening feels instant)
- Minimal code changes (< 50 lines added)
- All existing tests pass
- Pattern consistent with existing workspace switching behavior

## Open Questions

- Are there any apps that break when moved offscreen briefly?
- Should this be configurable via `~/.hyprspace.toml`?
- Should we add a small delay before hiding to allow any initial app setup?
