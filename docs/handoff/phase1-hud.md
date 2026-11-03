# phase1/hud

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ 7b8e6ec
- **Updated:** 2026-11-03

## J asked
"next task" → 1.5+ A4: "ไอคอนบอกตอนรีโหลดปืนอาจเป็นวงกลมและไหลจนเต้มวงกลมบนหัวตัวละคร hud แสดงเลือดสแตมิน่า".

## Done
- `ui/fighter_hud.gd`: HP / stamina bars (stance on the stamina bar, low-stamina flash, downed countdown) and the
  reload ring over each fighter's head (shell ticks for the pump shotgun, orange for a jam).
- horde_spike: the status line keeps only the gun; HP / stamina / stance / reload moved to the HUD.
- 2 new tests, 209 total, all passing on desktop.

## Not done / next
- A5: two AI teammates (they join `FighterHud.fighters` for their rings).

## J must test
- `?spike=arena`: are the bars readable at a glance on the Arc? Reload each gun: the ring fills over the head;
  the shotgun's fills one step per shell. Sprint until stamina runs low: the bar flashes. Get downed: the bar
  counts down.
