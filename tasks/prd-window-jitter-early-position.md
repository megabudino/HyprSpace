# PRD: Window Jitter Fix - Early Position (with Tahoe Animation)

## Introduction

Eliminate the visual jitter when new windows open by setting their **final tiled position immediately in the AX observer callback**, allowing macOS Tahoe's native window animation to smoothly animate the window to its tiled position. This builds on the "Early Hide" approach but predicts the final layout position instead of hiding offscreen.

## Prerequisites

This PRD assumes "Early Hide" (prd-window-jitter-early-hide.md) is implemented first. The infrastructure for synchronous window discovery and early interception will be reused.

## Background

macOS Tahoe introduced smooth window opening animations. By setting the correct final position before this animation begins, we can have windows animate directly to their tiled position—providing the best possible visual experience.

## Goals

- Eliminate visible jitter when new tiling windows open
- Preserve macOS Tahoe's native window opening animation
- Windows animate smoothly from center/zero to tiled position
- Graceful fallback to "Early Hide" if prediction fails
- Handle all window types correctly
- Support multi-monitor setups

## User Stories

### US-001: Create layout position predictor
**Description:** As a developer, I need to predict where a new tiling window will be placed so I can set that position before the animation starts.

**Acceptance Criteria:**
- [ ] Create function `predictTiledRect(for monitor: Monitor, workspace: Workspace) -> CGRect`
- [ ] Prediction based on MRU window's parent container and position
- [ ] Accounts for current number of windows in container
- [ ] Respects gaps and padding configuration
- [ ] Returns approximate rect (exact match not required, layout will correct)
- [ ] Typecheck passes (`./build-debug.sh`)

### US-002: Set predicted position in observer callback
**Description:** As a user, I want new windows to animate smoothly to their tiled position.

**Acceptance Criteria:**
- [ ] In `refreshObs`, after identifying new window:
  - Get focused workspace and its monitor
  - Call `predictTiledRect` to get target position
  - Set window frame to predicted position (synchronously)
- [ ] Do NOT call `disableAnimations` for this initial frame set
- [ ] macOS Tahoe animation runs, window "grows" to tiled position
- [ ] Typecheck passes (`./build-debug.sh`)

### US-003: Handle prediction for different layouts
**Description:** As a developer, I need the predictor to work with tiles, accordion, and dwindle layouts.

**Acceptance Criteria:**
- [ ] Predictor handles `tiles` layout (equal splits)
- [ ] Predictor handles `accordion` layout (stacked with one expanded)
- [ ] Predictor handles `dwindle` layout (fibonacci-like splits)
- [ ] Uses current container's orientation (horizontal/vertical)
- [ ] Typecheck passes (`./build-debug.sh`)

### US-004: Fallback to hide if prediction unavailable
**Description:** As a developer, I need a fallback when prediction isn't possible.

**Acceptance Criteria:**
- [ ] If workspace/monitor info unavailable, fall back to hide offscreen
- [ ] If layout state is ambiguous, fall back to hide offscreen
- [ ] Fallback uses same "Early Hide" logic
- [ ] No jitter in fallback case
- [ ] Typecheck passes (`./build-debug.sh`)

### US-005: Handle prediction mismatch gracefully
**Description:** As a user, I don't want to see a second jump if the prediction was slightly off.

**Acceptance Criteria:**
- [ ] `layoutWorkspaces()` uses `disableAnimations` when correcting position
- [ ] If predicted position matches final position, no correction needed
- [ ] If mismatch, correction is instant (no visible jump)
- [ ] Typecheck passes (`./build-debug.sh`)

### US-006: Skip animation for rapid window creation
**Description:** As a user creating many windows quickly, I want consistent behavior.

**Acceptance Criteria:**
- [ ] When multiple windows created rapidly, each gets predicted position
- [ ] Tree state may change between prediction and layout—handled gracefully
- [ ] No race conditions or crashes
- [ ] Typecheck passes (`./build-debug.sh`)

### US-007: Handle popup and dialog windows
**Description:** As a user, I want popup and dialog windows to use their natural macOS animation.

**Acceptance Criteria:**
- [ ] Detect window type synchronously
- [ ] Skip position prediction for popups/dialogs
- [ ] Let macOS handle their natural animation
- [ ] Typecheck passes (`./build-debug.sh`)

## Functional Requirements

- FR-1: Create `predictTiledRect(for:workspace:)` function
- FR-2: Set predicted position synchronously in observer callback
- FR-3: Do not disable animations for initial position set
- FR-4: Support all layout modes (tiles, accordion, dwindle)
- FR-5: Fall back to hide offscreen if prediction fails
- FR-6: Correct mismatch instantly (with disabled animations) in layout pass
- FR-7: Skip prediction for popup/dialog windows

## Non-Goals

- No custom animation implementation
- No animation configuration (duration, easing)
- No support for pre-Tahoe macOS (animation is a bonus)
- No exact prediction match required (layout will correct)

## Technical Considerations

### Prediction Accuracy
- Prediction doesn't need to be pixel-perfect
- Layout pass will correct any mismatch (with disabled animations)
- Main goal: get close enough that Tahoe animation looks natural

### Layout Extraction
- May need to extract parts of `layoutRecursive` logic
- Or create simplified prediction that approximates the result
- Trade-off: accuracy vs. code duplication

### Timing
- Must set position before Tahoe animation starts
- Animation typically begins ~16-50ms after window creation
- Synchronous AX call should be fast enough

### Key Files to Modify
- `Sources/AppBundle/layout/refresh.swift` - Replace hide with position prediction
- New file: `Sources/AppBundle/layout/predictTiledRect.swift`
- `Sources/AppBundle/layout/layoutRecursive.swift` - May extract shared logic

## Success Metrics

- Zero visible jitter when opening new tiling windows
- macOS Tahoe animation preserved (window animates to tiled position)
- Popup/dialog windows use natural macOS animation
- No visible correction jump after layout
- All existing tests pass

## Open Questions

- How accurate does prediction need to be for animation to look good?
- Should we cache layout state for faster prediction?
- How to handle apps that create windows with unusual timing?
- What's the animation timing on different Mac hardware?
