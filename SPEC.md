# Flappy Clone: Lean Spec (Godot 4, low-token build)

Goal: a fully playable, polished-enough Flappy Bird clone in **Godot 4 (latest 4.x), typed GDScript**, built by Claude Code with **minimum tokens**. Proof of concept that human + AI can make a fun game.

## Token rules for the agent (follow strictly)
- Read this file once. Don't explore the project beyond `art/` and files you create.
- Write each file once, completely. No refactors, no extra features, no long explanations.
- Verification = **one** parse check only: `godot --headless --path . --quit`. Fix errors, don't re-run more than twice.
- No tests, no autotest, no screenshots. The human playtests.
- Final report: max 5 lines (files created, how to run, anything manual).
- Godot 4 APIs only (`@export`, `@onready`, `create_tween()`, `CharacterBody2D`, `connect(callable)`). Never Godot 3 syntax.

## Assets (provided by the human)
- Bird and pipe SVGs are in `res://art/`. Glob `art/*.svg` to find the exact filenames; don't ask.
- Godot imports SVG natively. Scale sprites in code to the sizes below; don't edit the SVGs.
- If the pipe SVG is a single pipe, use it for the bottom pipe and flip it vertically (`flip_v`) for the top pipe.
- Everything else (sky, ground, UI) uses simple shapes/colors: `ColorRect`, `Polygon2D`, Labels. No other asset files.

## Project settings (`project.godot`)
- Viewport 288×512, stretch mode `canvas_items`, aspect `expand`, window 432×768, portrait.
- Default texture filter Linear (SVGs look smooth).
- Input action `flap`: Space, Up, Left Mouse Button, Joypad A. Enable "emulate mouse from touch".
- Main scene `res://main.tscn`.

## Files (keep it to these)
```
project.godot
main.tscn          # root Node2D, minimal; everything else built in main.gd
main.gd            # game state, spawning, scoring, UI, save
bird.gd            # bird movement + tilt + squash
pipe_pair.gd       # top/bottom pipe + score zone
sfx.gd             # procedural sound effects (no audio files)
art/*.svg          # provided
```

## Game loop (`main.gd`)
States: `READY → PLAYING → DEAD → GAME_OVER`.
- **READY:** bird bobs (sine, ±4 px). "Tap to start" label. First flap → PLAYING.
- **PLAYING:** gravity on, pipes spawn every 1.45 s, score counts.
- **DEAD:** on hit: play `hit`, white flash (ColorRect alpha 0.8→0 in 0.2 s), camera shake (0.25 s, 4 px), stop scrolling and spawning, bird falls to the ground, then play `die`.
- **GAME_OVER:** panel slides up (tween 0.4 s) showing Score, Best, medal text (Bronze ≥10, Silver ≥20, Gold ≥30, Platinum ≥40), "NEW!" if best. Restart button (or flap) after 0.5 s → reset to READY.
- Best score saved with `ConfigFile` at `user://save.cfg`.
- Flap handled in `_unhandled_input` so clicking the Restart button doesn't flap.

## Bird (`bird.gd`, CharacterBody2D or Node2D with manual movement)
| Param | Value |
|---|---|
| x position | 80 |
| gravity | 1250 px/s² |
| flap velocity | -330 px/s (set, don't add) |
| max fall | 480 px/s |
| size | ~34×24 px (scale SVG to fit) |
| hitbox | circle, radius ~10 px |
| tilt | -25° on flap, rotate toward +90° at 480°/s after 0.35 s |
| juice | on flap: scale (1.15, 0.85) → (1, 1) in 0.1 s |

Dies when touching a pipe, the ground (y = 400), or the ceiling (y < 0).

## Pipes (`pipe_pair.gd`, Area2D-based)
| Param | Value |
|---|---|
| scroll speed | 120 px/s (ground scrolls at the same speed) |
| width | 52 px |
| gap | 110 px |
| gap center | random 140–300 px, max change 120 px from previous |
| spawn | right edge + 30 px; free when off left edge |
- Score zone: Area2D across the gap; +1 once per pair, play `point`, score label punch (scale 1.25 → 1 in 0.15 s).
- Simple `queue_free` is fine (no pooling needed at this scale).

## Visuals
- Sky: vertical gradient (`GradientTexture2D` on a TextureRect) light blue → pale cyan.
- Background: 2–3 soft hill `Polygon2D`s scrolling at 0.3× speed (parallax), wrapping.
- Ground: tan `ColorRect` at y 400–512 with a darker stripe band on top that scrolls at 1.0× (two copies leapfrogging).
- Score: big white Label with dark outline, top center.
- Panel: rounded `Panel` with StyleBoxFlat.

## Sound (`sfx.gd`, procedural `AudioStreamWAV`, 22050 Hz mono 16-bit)
| Id | Sound |
|---|---|
| flap | short noise burst with rising pitch, 0.08 s |
| point | two square tones 988 Hz → 1319 Hz, 0.07 s each |
| hit | 120→60 Hz triangle + noise, 0.15 s |
| die | sine sweep 600→150 Hz, 0.4 s |
Small pool of 4 `AudioStreamPlayer`s.

## Build order (2 prompts max)
1. **Prompt 1:** create all files above and make the full loop playable (bird, pipes, scoring, states, UI, save, visuals, sound). One parse check.
2. **Prompt 2 (only if needed):** fix whatever the human reports after playtesting.

Later (separate, when tokens allow): feel tuning, Web/Android export, 3D version.

## First prompt for Claude Code
> Read SPEC.md and follow its token rules. Build the whole game in one go, run one parse check, and report in max 5 lines. My Godot executable is: `<path>`
