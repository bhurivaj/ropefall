# Changelog

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
