# phase1/stances

- **PR:** #44 (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ 2e759c5
- **Updated:** 2026-11-03

## J asked
"Start A3": "กดCนั่งยอง กดZนอน กดshiftวิ่งเร็ว กดcontrolกลิ้งหลบ (มีผลต่อความเเม่นปืน เสียง ระยะถูกตรวจจับ)";
the roll is on Space instead of Ctrl (J chose it: Ctrl+R / Ctrl+W are browser shortcuts).

## Done
- `combat/fighter_motion.gd` + `combat/movement_config.gd` + `data/combat/movement.tres`: stances, sprint, roll,
  stamina; multipliers for speed, spread, step noise, seen-from.
- `SpikePlayer`: C / Z / Shift / Space (pad L3 / B / D-pad down / up); steps emit `noise` + `footstep`;
  roll moves 3 m with i-frames (`FighterHealth.dodging`); no shooting while sprinting or rolling; the body
  follows (kneel, crawl, run with high ready / port arms, roll); tracers and the aim line come from the muzzle.
- `Horde.perceive(target, delta, seen_mul)`, `InteriorHordes.step(..., seen_mul)`, `Gun.stance_spread_mul`.
- Audio: the footstep sound comes from the player's steps, as loud as their noise.
- HUD: "Stamina N" and the stance after HP (bars come with A4).
- J's round 2: "1.แอนิเมชั่นการเดินแปลกๆ ไม่สอดคล้องกับทิศทางเดิน 2.เงาตัวละครไม่มี 3.ซอมบี้ตอนโดนระเบิดจะหันหน้าไปที่
  ศูนกลางระเบิดเสมอทั้งที่โดนระเบิดจากข้างหลัง 4.แอนิเมชั่นรีโหลดอยากให้แสดงออกชัดเจนกว่านี้" →
  1. 4-way walk and crouch walk (BlendSpace2D by direction against the aim); sprint / roll face their direction.
  2. survivor.glb.import: create_shadow_meshes and generate_lods off (the skinned shadow mesh drew nothing).
  3. CorpseLayer: a blast from behind throws the body on its face (keeps facing away, death clip).
  4. Reloads: mags are separate meshes (kit_guns MAGS + GunModel.mag_scene / mag_hand_scene / hand_points);
     LeftHandIK walks the hand through SurvivorView.REACH (mag well, pouch, handle, port); the empty mag drops.
- Godot 4.7 gotcha: a const `Dictionary[K, PackedStringArray / PackedFloat32Array]` built from literals reads back
  empty strings / zeros; use `Array` values (an empty animation name in a BlendSpace2D crashed the engine).
- 9 new tests, 202 total, all passing on desktop.

## Not done / next
- J should re-check the four round-2 points.
- A4: HP and stamina bars, reload ring above the head.
- The roof horde always hunts, so stealth shows only inside buildings (`?spike=interior`).
- Pad changes not tried on a pad (J deferred pad tests).

## J must test
- `?spike=arena`: C, Z, Shift, Space. Do the speeds feel right? Is the roll useful to get out of a crowd
  (zombie hits miss for 0.35 s)? Does stamina run out at the right time? Numbers: `data/combat/movement.tres`.
- Crouch / prone and shoot: the crosshair should tighten. Sprint: you can't shoot, the gun goes to high ready /
  port arms.
- `?spike=interior`: prone near sleepers: they should notice you later than standing.
