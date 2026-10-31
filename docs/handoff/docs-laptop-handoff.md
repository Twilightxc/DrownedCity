# docs/laptop-handoff

- **PR:** none. This branch only carries this note, so `tools/handoff.sh` shows it on the other machine. Delete
  the branch once its items are picked up (`git push origin --delete docs/laptop-handoff`).
- **Machine:** written on the laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `f0c9732` (everything merged: #24–#31; Phase 0 passed, Phase 1 plan in `docs/PHASE1.md`)
- **Updated:** 2026-10-31

## J asked
"จะสลับเครื่อง". Open thread before the switch: J asked "ระบบพลเมืองดีเด่นออกแบบไว้ยังไง" and said they would send more
detail ("ขอแจ้งข้อมูลเพิ่ม"). The detail has not arrived yet.

## Done (laptop, 2026-10-29 … 31)
- 0.8 part 2, its fixes and the "Flooded" sign; 0.8 passed on Arc web.
- Roof props block only the cells under them (#31).
- Phase 0 exit review (#29) and the Phase 1 plan (#30): no cuts, combat first, demo zombies Walker / Runner /
  Armored / Bloater, arena = the base roof, Mixamo when needed.

## Not done / next
1. **Citizen system ("พลเมืองดีเด่น")** — waiting for J's detail. What the GDD has today: status ladder
   stranger → member → outstanding citizen → leader (§3); the first outstanding citizen can be made leader, and
   the leader's personality picks a special room + endgame goal (§12, 4 leader types). Not designed yet: how a
   survivor moves up (criteria), what an outstanding citizen gets besides leader eligibility, how many, losing
   the status, link to influence (§11), where the leader personality comes from. When J's detail arrives:
   write it into GDD §3 / §12 and add it to step 1.6 (SimCore) in `docs/PHASE1.md`.
2. **Phase 1 step 1.1 weapons from data** (`docs/PHASE1.md`): code on either machine; gun meshes need Blender
   (desktop).
3. J's web check of #31 (walk between the two east AC units, and between AC3 and the sandbags) and of the
   "Flooded" sign (`?spike=interior&storey=1`) — not reported yet.

## J must test
See item 3.

## Next session must know
- `docs/arc-handoff` is obsolete; delete it.
- Laptop: Godot 4.7.2 was in the old session's scratchpad; a new session needs it downloaded again (ask J).
