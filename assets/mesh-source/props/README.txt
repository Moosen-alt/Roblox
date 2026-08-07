Openable Chest Pack

Files:
- chest_base.obj              Static base of the chest
- chest_lid.obj               Separate lid mesh for open/close animation
- chest_closed_preview.obj    Preview of chest in closed position
- chest_open_preview.obj      Preview of chest in open position

Recommended Roblox setup:
1. Import chest_base.obj and chest_lid.obj with 3D Importer.
2. Put both parts into one Model.
3. Set the lid pivot near the back top edge of the base, like a hinge.
4. Use TweenService or Motor6D/CFrame animation to rotate the lid open.

Suggested starting layout:
- Base stays anchored
- Lid starts slightly above the base
- Lid opens around X rotation by about -100 to -120 degrees

Notes:
- Low poly and lightweight for animation tests
- Neutral wood-and-metal style shape
- Separated specifically so you can animate the lid opening
