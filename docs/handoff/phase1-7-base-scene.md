# phase1-7/base-scene

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ 3e73d8d
- **Updated:** 2026-11-07

## J asked
"next" → 1.7 step 3: the base scene on the arena roof. J chose (2026-11-07): **its own scene `?spike=base`** (not
merged with the arena; day/night with the horde waits for 1.10) and **new daily-life clips now**.
Then (2026-11-07): "อยากให้มีรายละเอียด ลูกเล่น ดีเทลมากกว่านี้ เช่นตอนกลางคืนก่อไฟมีแสง เปลวไฟ ผู้รอดชีวิตก่อไฟในถัง
แปลงผักปลูกหลายแบบ มีการเติบโต รดน้ำ ใส่ดินใส่ปุ๋ย พรวนดิน ชื่อตัวละครไม่ใช้ชื่อแบบไทย" — done in the second commit.

## Done
- `tools/blender/kit_survivor.py`: 9 whole-body clips with empty hands: stroll (1.4 m/s), sleep, sit, read, chat,
  work_kneel, work_stand, exercise, watch. `SurvivorView.live(clip, speed)` plays them; the pose gallery shows them.
- `tools/blender/kit_base.py` → `assets/models/room_*.glb` (16) + `data/base/room_kit.json`:
  - sleeping: tents (4 bedrolls under A-frames) / cots (6, a blanket screen)
  - farm: soil beds (3 planters) / greenhouse (staked crops, hoop frame, plastic at the back)
  - infirmary: sick bay (2 cots, screen, crate table) / clinic (3 beds, curtains, cabinet)
  - water: rain barrels under a tarp funnel / filter (tank on a stand, pipes)
  - kitchen: campfire with 3 logs / brick stove, table, crates
  - watchtower: sandbag U / wooden tower with a 2.4 m deck and ladder
  - site_large / site_small (construction), site_pile (upgrade), crate_seat (reading on the roof)
  - 24–2332 tris each; nothing covers the middle of a room, so the camera sees in.
- `data/base/roof_layout.json`: 6 slots clear of the roof props, roof spots (read, exercise, gather, floor beds,
  stroll points, exit), 10 s per game hour, speeds 1 / 3 / 10.
- `game/base/`: `BaseKit` (models + spots in world space), `LifeSpots` (pure: who goes where, beds like
  `BaseRules.hour_mods`), `BaseNav` (0.5 m grid + AStarGrid2D, string-pulled), `Resident` (walks, settles, name
  tag), `BasePreset` (start / tier1 / tier2 test bases, 5 people, a book on the shelf), `base_spike` (clock, speed,
  F5 rooms, F3 lines per survivor, night dimming).
- `SimState.start_day()` (the morning alone, for hour-by-hour scenes). life.json night pull 1.0 → 1.5.
- Captures: `docs/art/23_base_tier1_day.png`, `docs/art/24_base_tier2_evening.png`. Desktop: 144 FPS (vsync),
  76–82 draw calls, 90–110k prims for the whole view.
- 10 new tests (`tests/game/test_base_scene.gd`); 373 passing.

## Details pass (J's second request)
- Fires (`game/base/base_fire.gd`): flame billboards (FireFx's material), sparks (CPUParticles3D), a flickering
  OmniLight, no shadow. Kitchen campfire / stove: lit while someone cooks and 17:00–23:00. Two oil drums
  (`prop_fire_barrel`, layout `fire_barrels`): from 18:00 the nearest free survivor walks over, kneels and lights
  each one (`Resident.errand`, the log says who); out at 07:00. At night company warms its hands round them.
- Farm (`game/base/farm_look.gd`, layout `farm`): planters grow tilled → sprouts → young → grown → ripe every 12 farm
  work-hours (`RoomState.worked`, save schema 9), staggered; crops tomato / cabbage / corn / beans, herbs in the last
  bed while herbs are queued. Tenders hoe (hand_hoe), sow and feed, water (hand_can), weed, harvest by stage. Compost
  box and sacks by the beds. Readers hold a book (hand_book). `SurvivorView.hold(scene)`.
- Clips: till, water, warm_hands. Camera: 4 zoom steps (the closest for details), WASD / left stick pans, `&focus=x,z`.
- Names: Mara, Elias, Rosa (founders, `base_economy.tres`), Ana, Viktor, Joe (extra).
- 6 more tests; 379 passing. Captures: `docs/art/25_base_night_fires.png`, `docs/art/26_base_farm_close.png`.

## Not done / next
- Step 4: the UI (build / upgrade / queue / assign, gamepad). Until then F5 swaps the test bases.
- Step 5: Observer mode.
- People don't avoid each other; no ladder climb (they pop up onto the tower deck).
- No sound yet (fire crackle, hoe, water) — the CC0 packs could cover it.
- Not measured on the Arc yet.

## J must test
`?spike=base` (also `&rooms=tier2`, `&hour=19`, `&speed=3`). Watch a day at 3× or 10×:
1. Do the rooms read at a glance (tier 1 vs tier 2, the infirmary site in "start")?
2. Do people look alive: walking, working at the planters / stove, sitting round the fire in the evening, sleeping
   in beds, reading on the crates, a guard on the tower? Any clip that looks wrong (`?spike=poses`, last row)?
3. Is the night too dark or not dark enough? Do the fires and drums read? Does someone go and light the drums at 18:00?
4. Zoom in (wheel, WASD to pan) on the farm: do the beds grow and change crops, and does the tender hoe, water, kneel?
5. Arc: FPS in F3 with 5–6 people (`&people=6`), at night with the fires lit.

## Next session must know
- Room spots come from kit_base.py: change a room there and re-run it, never edit room_kit.json.
- `--capture=<png> --capture-frames=N` (DebugOverlay) works for any spike: `-- --spike=base --capture=...`.
- A `-s` SceneTree script can't compile a scene that uses the `DebugOverlay` autoload.
