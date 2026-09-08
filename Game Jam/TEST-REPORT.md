# Verification — STILL//MOVING 0.4

Original pass: Godot 4.5.2, Windows, OpenGL compatibility renderer, NVIDIA RTX 3050 Laptop GPU.

Re-run after the 4.7.2 engine upgrade and the `scripts/` reorganisation: Godot 4.7.2, Linux, headless. Core 84/84, mechanisms 51/51, boss 33/33, authoring 12/12, and all four routes pass with identical timings. The rendering-performance and human-playtest notes below still come from the original Windows pass.

- 84 core checks passed: movement, double/wall jumps, finite grip, dashes, downward strike, freeze, checkpoint accounting and four-level flow.
- 51 mechanism checks passed: cover, firing, gates, barriers, pads, fields, swept collisions, frozen danger and reusable sensors.
- 33 boss checks passed: frozen warnings/rig/fire/light, safe fire responses, solid claw/wave damage, two volley patterns, recharge limits, one hit per strike/opening, half-health transition, defeat, reset during every attack, and stationary strike clock commitment.
- All four routes completed using ordinary input commands and actual physics. No route teleports, disabled hazards, invulnerability cheats, or direct boss damage. The separate unit fixtures use controlled placements to isolate edge cases.
- Latest complete campaign route: FIRST TICK 31.27s active; EYES ON YOU 32.65s; BROKEN GEARS 28.77s; THE LAST FLAME 88.48s, comprising about 19s approach and 69.45s boss. These machine routes fall below the initial 45–75s target for levels 1–3; compactness was retained instead of adding empty travel. Human learning, observation and retries add real time. Human difficulty testing remains outstanding.
- Boss victory used eight recovery hits, both phases and all three attacks, with more than 60s remaining in its separate 130s budget. The arena route is winnable without spending dash charges; recovery cells provide additional options.
- Rendering inspected at the actual 320x180 game resolution and at 1280x720 presentation. Six fireballs, animated rig and lights: median frame 16.67ms, p95 16.81ms, p99 16.92ms across 150 samples after warmup.
- Native tile editing and reusable assets remain supported. The save/reload test uses a temporary file inside the project because this session cannot write the normal user-data directory.

Limitations: keyboard controls; no persistent saves or external human playtest. The maps use folded compact courses and tall wall climbs, not separate loading screens for each encounter. Some renderer shader-cache and Windows certificate-store messages arise under the restricted test environment; these did not prevent successful rendering or gameplay. The final defeat animation obeys world time, so keep moving to watch it finish.

Final authoring verification: all 12 paint/erase, save/reload, reusable behavior and F6 checks passed.

## Presentation update — 2026-09-08

Verified on installed Godot 4.6.2, GL Compatibility, NVIDIA RTX 3050 Laptop:

- `core_tests.gd`: 87 checks, zero failures; existing motion/state timing preserved.
- `mechanism_tests.gd`: 51 assertions, zero failures.
- `boss_tests.gd`: 33 checks, zero failures.
- `authoring_tests.gd`: zero failures; real tile/object edit, save/load round trip,
  direct F6 room startup and replay checked. Core/authoring report an ObjectDB
  shutdown warning; the presentation runtime completed without this warning.
- `presentation_tests.gd -- --capture`: zero failures. Real GUI keyboard focus,
  editor access, Escape return and mouse new-game entry; automatic story 13.582 s;
  all four story beats, continue/skip and held-input suppression checked.
- Portal completion to restored control: **2.368 / 2.374 / 2.360 s** at 1280×720.
  Exactly one completion/load per exit, no clock progression, no accidental death,
  correct next costume/spawn, retries without story, and final completion checked.
- 1920×1080 portal: **2.374 s**; median frame 6.96 ms, p95 7.80 ms, max 12.74 ms.
- GPU captures inspected for both story illustrations/dialogue, every costume and
  21 shared poses, portal departure/tunnel/arrival, menu/editor and completion.
  UI/world sizing checked at 1280×720, 1920×1080 and 1000×800 with letterboxing.
  Existing `capture.gd` also passed at 640×360. Captures remain outside Git in /tmp.
- The menu launched the actual installed editor on `rooms/room_03.tscn`; its window
  title confirmed that scene. Keyboard selection of another room and return also worked.
- Synthesized portal PCM peaks: 10373 / 13986 / 10459 of 32767; existing -20 dB
  gain and Master bus retained. Playback code exercised; subjective listening
  was not performed. Exported-build fallback was reviewed, not run in an export.

Completion triggers in presentation checks are scripted using the actual goal
collision/rectangle and director; this was not a new full manual campaign playthrough.
No level scenes, physics constants, collision shapes or controller state rules changed.
