# Manaconda's Minigame Mayhem — Godot Spike

This throwaway spike measures the commit-to-playable cycle time for an agent-built Godot pipeline. The Jam scene is a small 2-on-2 arcade basketball core-loop probe: move, pass, jump-shot, loose-ball recovery, and a guaranteed dunk. Placeholder shapes are intentional; the test target is movement weight, timing, staging, and camera response.

## Pinned engine and render path

The project targets **Godot 4.6.3**, recorded as `4.6.3` in `GODOT_VERSION`. The GitHub Actions container uses `barichello/godot-ci:4.6`. That tag currently reports `4.6.stable` rather than `4.6.3`; the workflow logs the pin and actual engine version separately and relocates templates matching the container engine. The local Jam smoke check uses the exact 4.6.3 pin. The project is GDScript-only and uses the Compatibility renderer for desktop, mobile, and Web. Web thread support is disabled so the export runs from GitHub Pages without special response headers. For patch-identical CI, the container image or its engine/templates must be updated to 4.6.3.

## The loop

Push to `main` → GitHub Actions imports and exports the project → uploads the Web build as a Pages artifact → deploys it with `actions/deploy-pages` → play at <https://manaconda33.github.io/mayhem-godot-spike/>. Set **Settings → Pages → Build and deployment → Source → GitHub Actions** for this deployment path.

Read the Actions run duration to measure commit-to-playable cycle time. Each run logs its start timestamp and `godot --version`.

## Jam controls

| Action | Keyboard | Touch |
| --- | --- | --- |
| Move | WASD or arrow keys | Lower-left virtual joystick |
| Pass | X or J | PASS button |
| Jump, then release to shoot | Hold C or K, release at the apex | Hold and release SHOOT |
| Turbo | Hold Shift | Hold TURBO |
| Toggle staging debug | F1 | DBG button |
| Return to hub | Back button in the top corner | Back button in the top corner |

The three lower-right touch buttons are each 112×112 design pixels. Keyboard and touch both feed the same Godot input actions, including shoot press/release timing.

## Feel feedback map

Change values in `shared/jam_tuning.gd`; movement, timing, court geometry, staging, and camera tuning live there.

| Feedback | Tuning knobs |
| --- | --- |
| Players feel slow | `MOVE_SPEED`, `MOVE_ACCEL`, `TURBO_MULT` |
| Jump feels too floaty | `JUMP_HEIGHT`, `JUMP_RISE_TIME`, `JUMP_FALL_TIME` |
| Shots never fall | `SHOT_BASE_MAKE_PCT`, `SHOT_PERFECT_BONUS_PCT`, `PERFECT_WINDOW_FRACTION` |
| Camera lags on fast breaks | `CAMERA_LEAD`, `CAMERA_LAG_SPEED`, `CAMERA_MAX_SPEED`, `CAMERA_ACCEL` |
| Dunk camera push is too much | `DUNK_CAM_PUSH_PCT`, `DUNK_CAM_ENABLED` |
| Dribble looks frantic | `DRIBBLE_BOUNCE_RATE`, `DRIBBLE_MOVE_BOUNCE_BONUS` |
| Pass feels slow or floaty | `PASS_FLIGHT_TIME`, `PASS_ARC_HEIGHT`, `PASS_LEAD_DISTANCE` |
| Players look too large or small | `ATHLETE_NEAR_HEIGHT_PCT_TARGET`, `FAR_DEPTH_SCALE`, `NEAR_DEPTH_SCALE` |

The F1/DBG overlay reports camera zoom, visible-court percentage, and the controlled athlete's current screen-height percentage. At the design resolution, the rest camera targets 50% court coverage and a 33% near-side athlete height.

## Simplifications

- Defenders apply pressure and sag toward the teammate, but do not steal, block, or intercept.
- CPU athletes never gain possession; every reset gives the player team the inbound.
- Possessions are endless, with no clock, quarters, or opponent score.
- Shots use a simple make probability and a timed perfect-release bonus. Missed shots use a basic rim bounce and can be recovered only by the player team.
- Athletes, ball, court, crowd, and hoops are generated placeholder shapes; there are no ported or external assets.
- The roster is only the existing three-entry sample. Jam filters it to Manaconda and Paprika; the real 35-character roster is out of scope.

## Definition of done

- The Godot 4.6.3 Actions run imports and exports Web, then deploys the artifact through the GitHub Pages Actions source.
- The Pages link opens the hub on a phone browser in landscape, and Jam can be entered and exited.
- Move, pass/control transfer, jump-shot release, guaranteed close-range dunk, score/reset, and loose-ball recovery paths work.
- Debug staging numbers are inside the camera coverage and near/far athlete height targets.
- The Actions duration is available as the pipeline cycle-time measure.
