# PRD: Window Jitter Fix - Option C (Animated Layout)

## Introduction

Eliminate the visual jitter when new windows open by pre-calculating the target tiled position and setting it before the window's opening animation begins, allowing macOS Tahoe's native window animation to animate the window directly to its tiled position. This is the most complex approach but provides the best visual experience by preserving and leveraging the system's native animations.

## Goals

- Eliminate visible jitter when new tiling windows open
- Preserve macOS Tahoe's native window opening animation
- Window animates smoothly from zero/center to its tiled position
- Handle all window types correctly (tiling, floating, popup, dialog)
- Support multi-monitor setups
- Maintain acceptable performance

## User Stories

### US-001: Research macOS Tahoe window animation timing
**Description:** As a developer, I need to understand when macOS Tahoe's window animation starts and how early we can intercept to set the target frame.

**Acceptance Criteria:**
- [ ] Document when `kAXWindowCreatedNotification` fires relative to animation start
- [ ] Determine if setting frame before animation starts redirects the animation
- [ ] Test with multiple app types (native, Electron, Qt, etc.)
- [ ] Document findings in code comments or design doc

### US-002: Create pre-registration layout prediction
**Description:** As a developer, I need to predict where a new window will be placed before it's registered in the tree.

**Acceptance Criteria:**
- [ ] Create `predictTargetRect(for workspace: Workspace, windowType: AxUiElementWindowType) -> CGRect`
- [ ] Function predicts position based on MRU container and current tree state
- [ ] Function accounts for the new window's presence (simulates binding)
- [ ] Prediction matches actual position after full registration and layout
- [ ] Typecheck passes (`./build-debug.sh`)

### US-003: Set frame in AX observer callback before registration
**Description:** As a developer, I need to set the window frame as early as possible in the notification callback, before the animation begins.

**Acceptance Criteria:**
- [ ] In `refreshObs` or new dedicated observer, set frame immediately on notification
- [ ] Frame is set before `runRefreshSession` processes the window
- [ ] Use predicted target rect from US-002
- [ ] Typecheck passes (`./build-debug.sh`)

### US-004: Handle animation timing with frame setting
**Description:** As a user, I want the window to animate smoothly to its tiled position using macOS's native animation.

**Acceptance Criteria:**
- [ ] Do NOT call `disableAnimations()` for new window initial placement
- [ ] macOS Tahoe animation runs with our target position as destination
- [ ] Window appears to "grow" or "slide" into its tiled position
- [ ] Typecheck passes (`./build-debug.sh`)

### US-005: Handle popup and dialog windows correctly
**Description:** As a user, I want popup and dialog windows to use their natural macOS animation without redirection.

**Acceptance Criteria:**
- [ ] Popup windows are not given a predicted position
- [ ] Dialog windows are not given a predicted position
- [ ] Only tiling windows get pre-registration frame setting
- [ ] Native animations preserved for non-tiling windows
- [ ] Typecheck passes (`./build-debug.sh`)

### US-006: Handle floating windows correctly
**Description:** As a user, I want floating windows to animate to their natural position.

**Acceptance Criteria:**
- [ ] Floating windows are not given a predicted position
- [ ] `on-window-detected` callbacks can reposition as expected
- [ ] Typecheck passes (`./build-debug.sh`)

### US-007: Support multi-monitor configurations
**Description:** As a user with multiple monitors, I want new windows to animate to the correct monitor and position.

**Acceptance Criteria:**
- [ ] `predictTargetRect` uses correct monitor's rect based on focus or heuristics
- [ ] Windows animate to the correct monitor
- [ ] Test with 2+ monitors (can use DeskPad or BetterDisplay 2)
- [ ] Typecheck passes (`./build-debug.sh`)

### US-008: Handle prediction mismatches gracefully
**Description:** As a developer, I need to handle cases where the predicted position doesn't match the final position.

**Acceptance Criteria:**
- [ ] If prediction differs from final layout, `layoutWorkspaces()` corrects it
- [ ] Correction happens without animation (use `disableAnimations`)
- [ ] Fallback behavior is equivalent to Option B (hide-then-reveal)
- [ ] No visible glitches in mismatch cases
- [ ] Typecheck passes (`./build-debug.sh`)

### US-009: Ensure layout consistency after animation
**Description:** As a developer, I need the final layout pass to produce correct positions regardless of animation state.

**Acceptance Criteria:**
- [ ] `layoutWorkspaces()` is authoritative for final positioning
- [ ] Animation-set position is overwritten if incorrect
- [ ] Subsequent layout operations behave normally
- [ ] Typecheck passes (`./build-debug.sh`)

### US-010: Handle apps that don't support frame-during-animation
**Description:** As a developer, I need to gracefully handle apps that ignore or fight frame changes during animation.

**Acceptance Criteria:**
- [ ] Detect apps that don't respond to early frame setting
- [ ] Fall back to Option B behavior for problematic apps
- [ ] Consider app-specific configuration if needed
- [ ] Document known problematic apps
- [ ] Typecheck passes (`./build-debug.sh`)

## Functional Requirements

- FR-1: Create `predictTargetRect(for:windowType:)` function
- FR-2: Set predicted frame in AX observer callback before registration
- FR-3: Do not call `disableAnimations()` for initial placement of new windows
- FR-4: Skip prediction for popup, dialog, and floating windows
- FR-5: Handle multi-monitor setups using focus workspace's monitor
- FR-6: Fall back to Option B if prediction fails or app doesn't cooperate
- FR-7: Ensure `layoutWorkspaces()` corrects any prediction mismatches

## Non-Goals

- No custom animation implementation (rely on macOS native)
- No animation for window operations other than creation
- No animation preferences/duration configuration (use system defaults)
- No animation on older macOS versions without Tahoe animations

## Technical Considerations

- Most complex approach, highest risk
- Timing is critical: must set frame before animation starts
- May require hooking into AX observer at a lower level
- Prediction must account for tree state changes during async operations
- Some apps may not respond well to frame changes during animation
- May need app-specific allowlist/blocklist

### Key Files to Modify
- `Sources/AppBundle/tree/MacApp.swift` - Conditional animation disabling
- `Sources/AppBundle/tree/MacWindow.swift` - Pre-registration frame setting
- `Sources/AppBundle/layout/refresh.swift` - Early frame setting in observer
- New file: `Sources/AppBundle/layout/predictTargetRect.swift`

### Dependencies
- Requires macOS Tahoe for full benefit
- Requires understanding of AX notification timing
- Requires understanding of macOS window animation system

### Risks
- Animation timing varies by app and system load
- Prediction may not match final layout (tree changes during async)
- Some apps may fight or ignore early frame setting
- More complex = more bugs and maintenance burden

## Success Metrics

- Zero visible jitter when opening new tiling windows
- macOS Tahoe native animation preserved (window animates to tiled position)
- Graceful fallback for problematic apps
- Acceptable performance (< 50ms additional latency)
- All existing tests pass

## Open Questions

- Does `kAXWindowCreatedNotification` fire early enough to redirect animation?
- Which apps don't cooperate with frame changes during animation?
- Should we maintain an app allowlist for animation support?
- How do we detect if the animation was successfully redirected?
- Should this be configurable via `~/.hyprspace.toml`?
- What's the behavior on pre-Tahoe macOS versions?
