# phase1-7/base-ui

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ cbf5dae
- **Updated:** 2026-11-07

## J asked
"next" → 1.7 step 4: the base UI — build / upgrade / queue / assign, navigable by gamepad.

## Done
- `ui/base_panel.gd` (BasePanel): one panel on the right for the selected slot.
  - Empty slot: the rooms that fit (cost, work hours); greyed with the reason when not possible.
  - A room: tier and its facts (beds, guard posts, per-day output), build progress (and "nobody is working on it"),
    Upgrade (cost, reason), Production (queue with progress and Cancel; per recipe its inputs → outputs and
    +1 / +5 / + keep going; "Stalled: …" when inputs or a skill are missing), People (each with what they do now;
    press = pin here / unpin), Demolish (asks twice).
  - Every action is a BaseRules call; the scene re-runs daily life at once and redraws.
  - Stock bar bottom left.
- `base_spike`: click a slot (ray onto the roof), Tab / Shift+Tab or pad RB / LB step through slots; the slot gets an
  outline and the camera swings over it; Esc / pad B closes. Speed moved to 1 / 2 / 3 and pad LT / RT; P or Space
  pauses (Space presses the focused button while the panel has focus). The left stick pans only while the panel is
  shut; the right stick always. `&slot=N` opens the panel at start. Test base "new" (F5 / `&rooms=new`) = the real
  start: tents and rain barrels only.
- 6 tests (`tests/ui/test_base_panel.gd`); 385 passing. Capture: `docs/art/27_base_slot_panel.png`.

## Not done / next
- Step 5: Observer mode.
- Strings go through tr() but there is no CSV yet (English only, as everywhere).
- No mouse-hover highlight of slots; no sound on button presses.

## J must test
`?spike=base&rooms=new`: build a farm and a kitchen from the panel, watch people build them, queue food and meals,
pin someone, upgrade the tents, demolish something. Then the same with a pad only (RB / LB, D-pad, A, B).

## Next session must know
- The panel rebuilds every game hour and after each action; focus keeps its index.
