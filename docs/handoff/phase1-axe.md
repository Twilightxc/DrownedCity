# phase1/axe

- **PR:** opening (pushed? yes)
- **Machine:** laptop (ASUS, Arc 140V)
- **Base:** main @ 924dab5
- **Updated:** 2026-11-06

## J asked
"ทำงานโค้ดทั้งหมดก่อนส่งต่อเครื่องdesktop". The axe is the second demo melee weapon (DECISIONS 2026-11-06:
knife + axe in the demo).

## Done
- `data/weapons/axe.tres`:
  - 70 damage (pen M), hits 2 in a 140° cone, 1.6 m reach
  - 0.25 s wind-up, 0.8 s swing
  - 18 stamina per swing, 3 m noise, stagger 0.6 s, knockback 4.5
  - ×1.5 on sleepers (the knife: ×2.5)
- `LoadoutConfig.melee`: a loadout can bring its melee weapon; null keeps the fighter's knife. Jess (the shotgun
  loadout) carries the axe.
- `SpikePlayer._arm` takes the loadout's melee weapon and rebuilds the swipe to its arc and reach. Teammates
  update their brain's melee reach.
- `?melee=axe` (desktop `--melee=axe`) gives the player the axe to try.
- 2 new tests, 240 total, all passing. GL arena with `--melee=axe`: no errors.

## Not done / next
- Desktop: an axe model and a heavy slash clip (and the knife's light one).
- No melee sounds yet (SfxBank has none).

## J must test
- `?spike=arena&melee=axe`: does the axe feel heavy (slow, two at once, stagger)? Is 18 stamina too much?
- Jess with the axe under Hold fire / Melee only.
