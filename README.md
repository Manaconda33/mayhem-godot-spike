# Manaconda's Minigame Mayhem — Godot Spike

This throwaway spike measures the commit-to-playable cycle time for an agent-built Godot pipeline. It contains only a hub, two scene-switching stubs, and sample shared roster data; it does not port either browser game.

## Pinned engine

The project targets **Godot 4.5**, recorded as `4.5.stable` in `GODOT_VERSION`. The GitHub Actions container and its export templates use the same 4.5 release. The project uses GDScript and the Compatibility renderer for the Web export.

## The loop

Push to `main` → GitHub Actions imports and exports the project → the workflow deploys `build/web` to the `gh-pages` branch → play the build at <https://manaconda33.github.io/mayhem-godot-spike/>. The export has Web thread support disabled, so it does not require special Pages response headers.

Read the Actions run duration to measure commit-to-export cycle time. Each run also logs its start timestamp and the Godot version.

If the build deploys but the Pages link does not serve it, configure **Settings → Pages → Build and deployment → Deploy from a branch → `gh-pages`**.

## Out of scope

- Gameplay or porting either the kart racer or arcade basketball game
- Ported or external assets, addons, and plugins
- The real 35-character roster; the three roster entries here are sample data only

## Definition of done

- The 4.5 Actions run imports the project and exports the Web build successfully.
- The `gh-pages` deployment serves the hub on a phone browser in landscape.
- Both buttons open their stub scenes, each stub displays the shared sample roster, and its back button returns to the hub.
- The Actions duration is available as the pipeline cycle-time measure.
