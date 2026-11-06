# phase1/melee-sfx

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** `phase1/anim-melee` @ 34f38b2 (PR #68). Merge #68 first; this PR then shows only the sound change
- **Updated:** 2026-11-06

## J asked
Desktop list: melee sounds from CC0 packs, J approves the list first; `swing_sfx` / `hit_sfx` on `MeleeConfig`, played
on `SpikePlayer.meleed`. J: "Approve" (Weapon Textures pack, both parts).

## Done
- `tools/audio/build_sfx.py`: swing_knife_1–2, swing_axe_1–2, hit_axe_1–2; can rebuild a subset
  (`build_sfx.py <raw> <out> name...`).
- `data/audio/sfx_bank.tres`: events swing_knife, swing_axe, hit_axe.
- `MeleeConfig.swing_sfx / hit_sfx`; `SpikePlayer.swung` signal; `SpikeAudio` plays the swing at the start and the hit
  at the strike, for the player and teammates.
- `docs/audio/SOURCES.md`. 1 new test, 252 total, passing.

## Not done / next
- Gun icons (`WeaponConfig.icon`). Optional more barricade stages.

## J must test
- `?spike=arena`: X (knife) at air and at a zombie: a whoosh, then a wet hit. Switch to a teammate's view or listen to
  Marco / Jess under "Melee only". The axe loadout: a heavier whoosh and a thud.

## Next session must know
- Raw packs live only in the desktop scratchpad (`sfx_raw/medieval/x`); the repo keeps the cut .ogg files.
