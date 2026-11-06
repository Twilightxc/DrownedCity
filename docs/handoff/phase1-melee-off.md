# phase1/melee-off

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ 85895c0
- **Updated:** 2026-11-06

## J asked
"ตัดระบบอาวุธตีประชิดออกก่อน"

## Done
- `platform/features.gd`: `Features.melee = false`. SpikePlayer gets no `melee`, teammates' `melee_reach` is 0, the
  weapon panel drops the knife, the wheel greys out "Melee only" (`RadialMenu.disabled`).
- 2 new tests, 254 passing on desktop.

## J must test
- `?spike=arena`: X does nothing; "Melee only" is grey and can't be picked; teammates on Hold fire back off.

## Next session must know
- Turn melee back on: `Features.melee = true` (one line).
