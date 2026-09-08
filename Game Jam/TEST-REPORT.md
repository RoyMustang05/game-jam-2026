# Verification — STILL//MOVING 0.4

Godot 4.5.2, Windows, OpenGL compatibility renderer, NVIDIA RTX 3050 Laptop GPU.

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
