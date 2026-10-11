# Changelog

## [Unreleased]

### Added
- Catenary method: the settings window has Method — Drape over objects (simulation) / Catenary (instant hanging curve between the first and last point of the selection, ignores objects)

### Changed
- Ropes no longer stretch under their own weight: a length constraint keeps the rope close to its set length (within a few percent; short ropes pulled nearly taut can end longer), while still colliding with objects
- Re-simulating a rope made with 2.1.x keeps its stored percentage, so it now hangs tighter than before (2.1.x ropes stretched) — raise the percentage for the old sag
- Settings window size/position is reset once (it got taller)
- The "above the bottom of the model" check runs only for Drape, after Start

## [2.1.2] - 2026-10-11

### Fixed
- Fall… failed after the first use on macOS (settings were saved as JSON text, which SketchUp evaluates on read) — settings are now stored as Base64 and an unreadable value falls back to the defaults
- Esc (and now Enter) keep the rope immediately instead of waiting for the next simulation frame; the rope is also kept when SketchUp stops the animation itself — before, a slow frame or a camera tool left an unconfirmed rope that disappeared on the next tool
- Much smaller simulation area sideways and upward: the rope's reachable ellipsoid (+10% stretch) instead of a sphere with a 25% margin, nothing above the polyline's highest point; downward it reaches the model bottom again because a hanging rope stretches under its weight — far fewer collision faces in big models

### Changed
- Picking another tool while the rope is falling keeps the rope as it is (like Esc) instead of discarding it — Undo removes it

### Added
- Ruby Console shows the average frame time every 50 frames
- Status bar hint while falling: "Esc or Enter keeps the rope as it is now"
- Ruby Console shows how far the rope reached compared to its target length (to tune the simulation area)

## [2.1.1] - 2026-10-11

### Fixed
- Fall no longer seems to hang on big models: collision faces are read into memory instead of being copied into the model one group per face (no hidden helper group or tag is created any more)
- Whole groups / components far from the rope are skipped while collecting faces

### Changed
- Geometry on hidden tags no longer blocks the rope (it already did not count as the floor)
- The "complex model" warning now appears at 20,000 collision faces instead of 1,000

## [2.1.0] - 2026-10-11

### Added
- Settings dialog before every fall: rope length (percent of polyline or fixed length), line / tube, diameter, tube sides, smoothing, material
- Settings are remembered between sessions
- Rope length is shown in the status bar and in the rope group's name; initial polyline, settings and length are stored on the rope group
- Re-simulate: select a rope and run it again from its original polyline with new settings (replaces the old rope, one Undo)
- Ropefall toolbar with Fall and Re-simulate buttons

### Changed
- Menu moved from Draw → Ropefall to Extensions → Ropefall
- The simulation area is sized from the rope length, so long ropes no longer stop with "indexed fallroom too small"; if a rope still leaves it, the fall stops and keeps the current shape instead of failing

### Fixed
- A short rope high above the model, or a long rope from a folded polyline, no longer allocates a huge collision grid (the grid stays around the rope's reachable area and its cell count is capped)
- The simulation area now allows for the rope's springs stretching, so ropes stop less often with "rope left the simulation area"
- Re-simulating a rope that was moved or copied now starts from where the rope is, not from its original position
- An error while keeping the rope after it left the simulation area no longer leaves the undo operation open
- The model bottom (the floor the rope lands on) now counts only visible top-level geometry, is the same for Fall and Re-simulate, and is measured before Ropefall adds its own helper geometry
- The selected material is applied only to tubes (lines are not coloured any more)
- A warning is printed in the Ruby Console when the saved settings cannot be read
- A fixed rope length is limited to 10 times the polyline length (same as the 1000% limit)
- The rope length in the group name and status bar no longer starts with "~"
- The new rope is selected after a fall, so Re-simulate can be run again right away

## [2.0.1] - 2026-10-11

### Fixed
- `.rbz` put `LICENSE` at the archive root, so installing dropped it straight into the SketchUp Plugins folder — it now ships as `sketchrope_ropefall/LICENSE.txt`

## [2.0.0] - 2026-10-11

### Changed
- Target SketchUp 2024+ (Ruby 3.2)
- Version bumped to 2.0.0 (licence removal + new target)
- `build.sh` builds a plain `.rbz` named from `VERSION` (no Windows scrambler / wine)
- `.rbz` now includes the MIT `LICENSE`
- Errors during a fall are now shown in a message box instead of failing silently

### Fixed
- Error during a fall (e.g. rope leaves the indexed fall room, or user declines the "complex model" warning) left an open undo operation and a hidden collision group / helper layer in the model — now the operation is aborted and the model is left untouched
- Switching to another tool while the rope is falling left the animation running outside the undo operation — now the fall is discarded
- `select_tool null` (NameError) in the error handler of the Fall command
- Collision groups were erased while iterating `model.entities`

### Removed
- Time-limited licence system (3-day eval, then purchase page on sketchrope.com) and the "Request licence" / "Enter licence key" menu items — the project is MIT licensed
- Development-only code: `test.rb`, `drawResult`, animation frame export to hard-coded local paths, debug point dump in the Ruby Console
