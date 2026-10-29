# fix/interior-stairs-walls

- **PR:** opened with this commit (pushed: yes); J merges
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `4af4bee` (0.8 part 2 merged). PR #25 (0.8 verdict, docs + overlay) is separate; this branch
  doesn't touch `PHASE0_RESULTS.md` so the two don't conflict. Add the numbers there after both merge.
- **Updated:** 2026-10-29

## J asked
"แจ้งให้ทราบ กำแพงบังศัตรูจนมองเห็นได้แค่ระยะสั้นๆ ทางลงบันไดเดินแล้วติด". Walls fix: J picked "กำแพงทั้งชั้นสูงเอว".

## Done
- **Stairs stuck:** the flight is 1 cell wide. On the top storey the row beside it is floor, so the player can
  walk off-centre; past half way the storey below takes over, where that row is the closed flight down to the
  flooded storey, and the player's 0.3 m radius overlapped it: no move was allowed. The controller now holds
  the player inside the flight row while on a flight. Regression test added (fails without the fix).
- **Walls hide enemies:** the cutaway cut only the camera's side, so far walls hid zombies. Now every wall of
  the player's storey drops to waist height. Each storey's pieces have their own material (`storey_floor`), so
  only the player's storey is cut and the storey above still shades the interior (a height band left the
  3.2 m wall tops floating as white lines). `cut_toward` / `cut_toward_camera` removed.
- 123 GUT tests pass. Desktop GL on the Arc, storey 2 with 30 awake: 120–123 draws, ~157–159k primitives.

## Not done / next
- J's look on the web after merge; then record it in PHASE0_RESULTS (0.8).

## J must test (after merge, Chrome, Ctrl+Shift+R)
1. `?spike=interior&storey=2&wake=1`: zombies visible across the whole storey in lit rooms, at every Q/E angle?
2. Walk down the stairs hugging either side of the flight: never stuck?

## Next session must know
- `InteriorBuilder._storey_material(s)`: one duplicated cutaway material per storey.
