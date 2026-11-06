# phase1/gun-icons

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ 85895c0
- **Updated:** 2026-11-06

## J asked
"next" → the desktop list: gun icons, a side view per gun into `WeaponConfig.icon` (bug list item 17).

## Done
- `tools/blender/icons_guns.py`: renders each `gun_*.glb` from the right side (muzzle right, loaded mag on, pale
  studio-lit silhouette, transparent), same px per metre, cropped → `assets/ui/icons/gun_*.png`.
- The four weapon configs point at them; `WeaponPanel.icon_rect` fits an icon into a 170 × 30 box.
- 1 new test, 253 passing on desktop.

## J must test
- `?spike=arena`: the panel at the bottom right shows the gun's picture instead of its name; switch 1–4.

## Next session must know
- After changing a gun in kit_guns.py, rerun icons_guns.py.
