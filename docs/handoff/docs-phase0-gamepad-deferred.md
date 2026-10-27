# docs/phase0-gamepad-deferred

- **PR:** #15, CI green (run #43), ready to merge
- **Machine:** desktop (RTX 4080)
- **Base:** main @ `b4f4a70`
- **Updated:** 2026-10-27

## J asked
"0.5: ข้ามไปก่อนยาวๆ"

## Done
- `docs/PHASE0.md`, `docs/PHASE0_RESULTS.md`: 0.5 ✅ on mouse + keyboard; gamepad feel deferred by J, not a Phase 0
  exit blocker. `docs/DECISIONS.md`: 1 row (pad support stays a requirement in code).

## Not done / next
- Gamepad feel test, whenever J has a pad (no date).

## J must test
Nothing. Docs only.

## Next session must know
- Don't ask J for the gamepad test. Keep a pad path in every new input/UI and check it with scripted input.
