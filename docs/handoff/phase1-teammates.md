# phase1/teammates

- **PR:** #47 (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** phase1/hud (PR #46) on main @ 7b8e6ec
- **Updated:** 2026-11-04

## J asked
"next task" → 1.5+ A5: "เอไอเพื่อนช่วยยิง" (2 teammates, J's answer).

## Done
- `combat/teammate_brain.gd`, `combat/teammate_config.gd` + `data/combat/teammate.tres`, `combat/grid_path.gd`.
- `game/spikes/teammate.gd`: a SpikePlayer whose wishes come from the brain; revive by F (2 s); swaps to the pistol.
- SpikePlayer input goes through `_move_input / _wants_sprint / _wants_fire / _update_aim` (overridable).
- `Horde.extra_targets / extra_hits`; horde_spike `add_teammate()` (flow goals, hits, blasts, fx, audio, HUD).
- Arena: Marco (AR) + Jess (shotgun), restock each calm, orders (Follow / Hold here / Hold fire), summary line,
  `?mates=N`. HUD: names, mini HP bars, revive ring. Picture: `docs/art/11_teammates.png`.
- J (2026-11-04): "เปลี่ยนชื่อเพื่อน ไม่ใช้ชื่อไทยและไม่แสดงบนหัวตัวละคร / มีแถบการ์ดเล็กๆแสดงพลังชีวิต สแตมิน่า ชื่อของเพื่อน /
  เพื่อนจะยิงศัตรูที่อยู่ใกล้ตัวเองมากที่สุดก่อน" → Marco and Jess; team cards above the player's bars; protect_weight 0.
- J (2026-11-04): "เปลี่ยนโมเดลตัวละคร ไม่ให้ซ้ำกัน / โมเดลซอมบี้ที่หลากหลายถึงแม้จะเป็นชนิดเดียวกัน" →
  kit_survivor LOOKS = 3 (`SpikePlayer.body_look`, SurvivorView.set_look); kit_zombie: zombie_office, zombie_worker
  (HordeConfig.variants = 4, style_spike renderer models) and zombie_runner_b / armored_b / bloater_b (EnemyConfig.models).
  kit_zombie now writes each look's VatModel .tres; a new look's .glb.import still needs LODs and shadow meshes off.
- J (2026-11-04): "เวลาล้มนานขึ้นและสามารถยิงปืนพกได้" → downed_sec 20; SpikePlayer switches to the sidearm when
  down (`is_sidearm`, `_on_health_state`), aims and fires it, gives the long gun back on revive; `downed_aim` clip
  (kit_survivor) with its own gun hold; teammates think and shoot while down and stay horde targets.
- 8 new tests, 217 total, all passing on desktop.

## Not done / next
- Gate 1.G (J): play the arena 3× on the Arc, fun? ≥ 50 FPS at the biggest wave?
- Teammates don't revive the player, throw grenades, crouch, or take gas / fire damage yet.

## J must test
- `?spike=arena`: do the teammates help without stealing the fight? Compare with `&mates=0`.
- Tab: Follow me / Hold here / Hold fire. Let one get downed and help it up with F.
- Arc: FPS with three skinned bodies.
