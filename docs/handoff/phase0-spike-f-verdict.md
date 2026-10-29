# phase0/spike-f-verdict

- **PR:** opened with this commit (pushed: yes); J merges
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `4af4bee` (0.8 part 2 merged as PR #24)
- **Updated:** 2026-10-29

## J asked
J sent the Arc web screenshot of `?spike=interior&storey=2&wake=1` (build `4af4bee · #67`), then: "ห้องมืดจนกว่าจะ
มองเห็น ไฟฉายหันตามเมาส์ดี ลงชั้น 1 ผ่านประตูห้อง lobby แล้วรู้สึกเป็นธรรมชาติ เชือกที่ขอบดาดฟ้าฝั่งใต้ใช้ลงหน้าต่างและปีน
กลับได้ cutaway อ่านง่ายจากทุกมุมกล้อง".

## Done
- 0.8 marked ✅ pass in PHASE0_RESULTS and PHASE0 (59 FPS, 114 draws, 133k; every look/feel question yes).
- Overlay fix: Kills and Hits Taken now include the zombies inside the building.

## Not done / next
- **Phase 0 exit review:** every spike 0.1–0.8 has passed (0.5 gamepad deferred by J). Next is planning Phase 1
  (web demo vertical slice, GDD §15, §17), with J.
- Open questions from earlier: the demo cut list in GDD §17; Mixamo clips for the zombie (optional).

## J must test
Nothing new: the overlay fix only changes two numbers on the interior page (F3).

## Next session must know
- `docs/arc-handoff` is obsolete; delete it.
