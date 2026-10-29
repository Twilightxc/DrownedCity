# fix/flooded-sign

- **PR:** opened with this commit (pushed: yes); J merges
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `ff77131`; PR #27 (docs) is separate and touches no code
- **Updated:** 2026-10-29

## J asked
J was stopped on storey 1's landing: "มันเป็นบันไดลงต่อชั้นน้ำท่วมหรอ". Of the cues offered, J picked: "Flooded" sign.

## Done
- `InteriorController`: a "Flooded" `Label3D` over the top cell of every closed flight whose top storey is dry
  (here: storey 1's flight down to storey 0). Shows only on that storey within 3 m; text via `tr()`.
- Test (124 total); desktop GL screenshot shows the sign at the head of the flight.

## Not done / next
- Then the Phase 0 exit review and Phase 1 planning.

## J must test (after merge)
`?spike=interior&storey=1` starts on storey 1's west landing: "Flooded" shows over the flight going down.
