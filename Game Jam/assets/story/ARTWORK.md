# STILL//MOVING — cinematic artwork

Two original illustrations generated with the built-in image-generation tool
on 2026-09-08, then copied into this project without image postprocessing.
Neither is a gameplay screenshot. Dialogue is drawn separately by the existing
sharp text helpers. The images retain their original proportions and metadata.

- `broken_machine.png`: prehistoric clearing, damaged time machine; traveler
  at the left, machine at the right, room for a gentle zoom and horizontal pan.
- `prehistoric_danger.png`: a distinct dense green forest, traveler lost in
  front of a lurking raptor. The first illustration was the identity/style reference.

Prompt specifications used:

1. “Use case: illustration-story. Create one finished 16:9 landscape cinematic
   pixel-art illustration for STILL//MOVING, no text or typography. Rich handcrafted
   fine pixel clusters, sophisticated cinematic lighting, detailed 1990s adventure
   game background, sharp pixel edges, not blurry, not a gameplay screenshot.
   Scene: broken time machine in lush prehistoric jungle clearing at dusk.
   Recognizable protagonist Milo at left third, full body, small adult time traveler
   with oversized rounded ivory helmet, luminous cyan horizontal glass visor revealing
   a tiny warm face, dark undersuit, ochre stitched hide tunic with shaggy fur shoulder,
   leather belt pouch and boots, cyan glowing circular chronometer on chest and wrist.
   Traveler looks dismayed toward a damaged machine at right third. Machine is a tilted
   circular silver time portal apparatus with broken outer ring, exposed copper cables,
   cracked cyan core, scattered components, orange sparks and smoke visibly rising.
   Huge fern fronds, mossy rocks, giant ancient trees, distant volcanic hills, cyan light
   from machine mixing warm amber rim light and deep teal jungle shadows. Camera
   composition must support a gentle zoom to traveler then horizontal pan toward damaged
   machine: traveler center x=32%, machine center x=68%, both main subjects within middle
   65% vertically, foreground bottom 15% contains only low ferns and shadow for separate
   UI dialogue overlay. Expansive environmental detail, storytelling, clear silhouettes.
   No letters, no words, no speech bubbles, no panels.”
2. “Use the reference only for protagonist identity and pixel-art style. Create a
   SECOND DISTINCT new cinematic 16:9 landscape illustration for the next scene in
   STILL//MOVING, not an edit of the previous composition. Same Milo: rounded ivory
   helmet, cyan horizontal glass visor with warm face, ochre hide tunic, shaggy fur
   shoulder, dark undersuit, leather belt pouch and boots, glowing cyan circular chest
   chronometer and wrist device. Milo stands LOST in dense prehistoric woods at center
   x=44%, full body, looking uncertainly toward left while a clearly readable lit raptor
   lurks BEHIND him to the right at x=68%, head and claws peering from ferns, sleek alert
   silhouette, eye amber, no attack or gore. Rich green ancient jungle, enormous tree
   roots, dense intricate fern leaves, hanging vines, cyan-green atmospheric mist,
   shafts of golden light from canopy backlighting helmet and raptor silhouette.
   Rich detailed fine pixel-art, deliberate pixel clusters and stepped edges,
   cinematic color and lighting, match reference quality and identity. New closer
   forest composition, no machine, no volcano. Main character and raptor entirely
   within upper 75% of picture; bottom 20% only shadowy foreground ferns to leave room
   for separately drawn dialogue. Fill the image, no frame, no panels, no text,
   no letters, no speech bubbles. This image slowly zooms toward Milo in game.”

The gameplay traveler remains original code-native pixel artwork in
`scripts/actors/milo_figure.gd`, with quarter-world-pixel details and the existing
shared pose table. `traveler_layer.gd` draws it at window resolution using the world
camera's transform; no movement, collider or world viewport changes are needed.

Portal audio is original deterministic sine/noise synthesis in `sound_bank.gd`.
It uses the same AudioStreamPlayer, -20 dB gain and Master bus as the existing
sound effects, with soft envelopes and bounded PCM amplitudes. No external sound
files, licensed packs, plugins, shaders or rendering dependencies were added.
