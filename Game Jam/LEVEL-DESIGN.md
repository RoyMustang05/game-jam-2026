# Make your own level

Open **Open Editor.cmd** in Desktop → Game Jam. It opens the first editable room in Godot. The four campaign rooms are in **res://rooms/**. Double-click any room to edit it.

## Paint floors and walls

1. Click **2D** at the top, then **Floors** in the Scene tree on the left.
2. Open the **TileMap** panel at the bottom. Select a tile in its atlas, then left-click or drag on the level to paint. Right-click erases. **Ctrl+Z** undoes.
3. The atlas has four rows: prehistoric, temple, factory, future. Its three columns are **cyan top surface**, **solid fill**, and **decoration**. Use the first two columns for floors and walls. Paint the top surface across a platform and fill tiles underneath.
4. Each tile is **8 × 8 game pixels**, with collision already attached. Select **Decoration** in the Scene tree to paint scenery without collision.

The existing floor layer has a Y offset of 6 pixels to preserve the original floor hfours. Keep the Floors and Decoration transforms at their defaults. Move and paint individual cells instead. Use the TileMap panel to place tiles; the TileSet panel changes the shared tile definitions.

## Place an enemy with its ability included

1. Expand **res://assets/enemies/** in FileSystem, bottom-left.
2. Select the room root in the Scene tree. Drag **Spike.tscn** or **Watcher.tscn** from FileSystem into the 2D level.
3. Select the placed enemy. Its settings appear in the **Inspector** on the right.

| Asset | Built-in behavior | Settings to try |
|---|---|---|
| Spike | Patrols between two points; contact is dangerous | **Speed**; **Patrol Offset** X = 80 for an 80-pixel horizontal patrol; **Bounceable** allows a downward strike bounce |
| Watcher | Detects the player and fires when visible; walls block its sight and shots | **Fire Interval** = 1 for faster shots; **Speed** controls bullet speed; **Sight Range**, **Facing**, **Field Of View** |

Place a Spike's origin on the floor: its body extends upward. A Watcher's origin is its center. Moving an enemy moves its patrol with it. **Phase** changes its initial patrol position or firing cycle. Enemy appearance follows the room's chapter. Their surrounding gameplay boxes have been removed; Godot may still show editor selection outlines.

These assets work automatically inside any of these room scenes, including copies you make. They inherit the game's movement-driven clock: stop moving and their patrols and shots freeze. No signal connections or scripting are needed.

## Add platforms, dangers, and goals

Drag scenes from **res://assets/objects/** into the room the same way.

| Asset | Purpose |
|---|---|
| MovingPlatform | Moving floor; set Size, Speed, and Patrol Offset |
| Spawn / Exit | Player start / room finish; keep exactly one of each |
| Anchor | Checkpoint that restores dash charges |
| PhaseBarrier | Barrier that a temporal dash breaks |
| FragileBarrier | Marked floor broken by a downward strike |
| Gate | Opens and closes; tune Gate Period and Open Ratio |
| Pad | Downward-strike bounce pad; ordinary contact is dangerous |
| SlowField / FastField | Slows or speeds up nearby world mechanisms |
| Pit | Lethal spike strip; place in gaps and set Size |
| Sign | Message in the level; change Message in the Inspector |

Use **Size** to resize an object's gameplay area; keep node rotation at 0 and scale at 1. For Spawn, Exit, and Anchor the origin sits at the feet. Rectangular barriers, fields, pads, and pits extend right and down from their origin. Moving platforms use their center.

Select an existing object and **Ctrl+D** to duplicate, then drag it to its new position. **Delete** removes the selected object. You can select objects from the Scene tree when the viewport is crowded.

## Save and play

- **Ctrl+S** saves your room.
- **F6** plays the currently open room immediately. Enter after completing it replays that same room.
- **F8** stops the playtest and returns to editing.
- **F5** plays the full four-room campaign, using your saved room edits.
- Select the room root to change **Title**, **Chapter**, **Time Limit**, **Room Size**, or enable the delayed **Echo** enemy.

To experiment freely, use **Scene → Save Scene As** and save a copy such as `rooms/my_room.tscn`. F6 plays that copy. The campaign still uses `room_01.tscn` through `room_04.tscn`; edit those when you want to change the campaign itself. The Waypoints and Sign objects provide the original route hints; update or clear them when changing the route.

**First exercise:** open room_01, paint a small platform, drag a Watcher above the floor, set Fire Interval to 1.5, save, then press F6. Move to see it fire; stop to freeze its shots.

## Version 0.4 additions

The room root exposes Boss, Arena, and Retry Budget. Enable Boss only for a final arena; the supplied room_04 contains the tested arrangement. Pyrax belongs to the room system. Spike assets expose Lunge for deterministic crouch/lunge/recovery movement. Crusher.tscn exposes Size, Gate Period, and Phase. J is the new short temporal strike; X remains air focus. The four campaign layouts include taller wall climbs and condensed encounters.
