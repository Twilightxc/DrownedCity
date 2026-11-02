# phase1/weapons

- **PR:** opened with this commit (pushed: yes); J merges
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `f0c9732`
- **Updated:** 2026-11-02

## J asked
"เริ่มเลย" — Phase 1 step 1.1, weapons from data (`docs/PHASE1.md`).

## Done (details in `docs/PHASE1_RESULTS.md` 1.1)
- `WeaponConfig` with the GDD §6 schema; `Ballistics` (falloff, pierce, armor, DPS); `Gun` carried state
  (modes, bloom, reload, jams, wear); `AmmoPouch`; `AttachmentConfig`; `LoadoutConfig` / `WeaponSlot`.
- Four guns + four attachments in `data/weapons/`; spike loadout; HP rescaled to GDD (Walker 100).
- Player: keys 1–4 / pad R3, fire mode V / L3, HUD line, noise signal; interior flashlight needs the attachment.
- F4 panel scrolls and has rpm / spread / recoil per gun (summary prefixed by data file).
- 142 GUT tests pass (15 new); desktop GL autoshoot 60 FPS, 68–78 draws.

## Not done / next
- Gun and attachment models (desktop, Blender).
- 1.2 enemy types + perception (Walker, Runner, Armored, Bloater); `Horde.armor` is in place for Armored.

## J must test (after merge, Chrome, Ctrl+Shift+R)
`?spike=twinstick`: 1–4 to switch guns, V for AR burst, shotgun reload shell by shell (fire mid-reload),
silenced pistol, F4 to tune rpm / spread / recoil per gun. Does each gun feel different and right?
Inside (`?spike=interior&storey=2`): flashlight with the AR or pistol, none with the shotgun or DMR.

## Next session must know
- `data/weapons/spike_rifle.tres` is gone; scenes use `spike_loadout.tres` (`SpikePlayer.loadout`).
- `SpikePlayer.weapon`, `.ammo`, `.reload_left` are gone: use `.gun` (`Gun`) and `.pouch`.
- `InteriorHordeConfig.shot_noise` became `indoor_noise_mul`.
