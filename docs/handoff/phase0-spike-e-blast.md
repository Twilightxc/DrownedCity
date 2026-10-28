# phase0/spike-e-blast

- **PR:** opened with this commit (pushed: yes); J merges
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `2768428`
- **Updated:** 2026-10-28

## J asked
"ไม่วัดใน Chrome เต็มจอ, ระเบิดอยากให้เพิ่มเอฟเฟคแรงระเบิดพวกเขม่า ฝุ่น ควัน สะเก็ดระเบิดชิ้นส่วนขาดกระเด็นแบบสุ่ม และไฟสำหรับ
ระเบิดปกติอาจเป็นสะเก็ดเล็กๆติดบนพื้น ส่วนที่ติดบนตัวอยากให้ติดเฉพาะจุดเล็กๆไม่ใช่ทั้งตัว ถ้าติดทั้งตัวควรเป็นระเบิดไฟ"

## Done (0.7 part 4, details in PHASE0_RESULTS)
- Two grenades: frag (shrapnel, floor embers, spot fires) and incendiary (whole-body fire, ground fire).
  G / pad B switches; autoshoot alternates.
- Spot fire = one body part (shader bits 12–15 + a small flame); no spread, no lurch, not charred.
- Blast fx: fireball, shrapnel, soot, longer smoke, dust ring; limbs 1–2 per blast corpse, scattered.
- Flame quads got a soft texture (they read as squares before).
- 95 GUT tests pass; desktop GL on the Arc: 200 = 74–79 draws, ≤ 251k; 300 = ≤ 301k (just over).

## Not done / next
- Web measurement on the Arc after merge (`?spike=style&autoshoot=1`, then `]` for 300).
- One 49–62 ms frame ~1 s after the first incendiary blast in 2 of 3 desktop runs at 200; cause not found.
- 300 is now ~1 % over the primitive budget; levers in PHASE0_RESULTS 0.7 (lower corpse cap first).

## J must test
`https://twilightxc.github.io/DrownedCity/?spike=style` (after merge, Ctrl+Shift+R): throw with RMB, G to switch
Frag ↔ Incendiary (HUD shows which). Look for: soot / dust / shrapnel on a frag blast, small embers left on the
floor, zombies burning only on one spot after a frag; whole bodies burning only after the incendiary.
F3 overlay: Burning "x body / y spot", Embers.

## Next session must know
- `data/weapons/spike_grenade.tres` is now `incendiary_grenade.tres`; old docs still name it.
- `Grenades.exploded` now passes the `ThrowableConfig` (3 args).
