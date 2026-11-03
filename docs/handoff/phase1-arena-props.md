# phase1/arena-props

- **PR:** #48 (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ 745bd16
- **Updated:** 2026-11-04

## J asked
"มีงานอะไรที่ต้องใช้blederและยังไม่ได้ทำไหม" → Claude listed four placeholders → "ทำตามที่เสนอได้เลย".

## Done
- `tools/blender/kit_props.py`: prop_supply_crate, prop_barricade_planks_0..2, prop_barricade_pallet_0..2,
  prop_grenade_frag, prop_molotov.
- SupplyCrate uses the crate model; the arena builds each barricade from the pieces and swaps stage by HP;
  `ThrowableConfig.mesh_scene / mesh_scale / spin_deg_per_sec` (frag, incendiary = Molotov).
- `SurvivorView.set_holstered`: long guns on the back, a sidearm on the thigh (SpikePlayer calls it on every switch).
- 1 new test, 218 total, all passing on desktop. Picture: `docs/art/14_arena_props.png`.

## Not done / next
- Gate 1.G (J).
- Part B Blender work waits for it (base rooms, survivor bodies / outfits, boat, district buildings, bridges).

## J must test
- `?spike=arena`: let zombies break a barricade: boards should come off in two steps before it's gone. Do the crate,
  the Molotov and the frag read at a glance? Switch guns: the others should move to your back / thigh.
