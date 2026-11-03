# phase1/audio-pass-1

- **PR:** #42 (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ 15dea02
- **Updated:** 2026-11-03

## J asked
1.5+ A1 (PR #40 plan): "ใส่เสียงปืน ระเบิด เสียงซอมบี้". J approved all 9 CC0 packs ("Approve all 9").

## Done
- `docs/audio/SOURCES.md`: the 9 packs, authors, licences, what each is used for.
- `tools/audio/build_sfx.py`: cuts them into 34 mono Ogg files in `assets/audio/` (0.31 MB). Needs ffmpeg + numpy;
  raw packs were in the desktop scratchpad, not the repo.
- `audio/`: `SfxEvent`, `SfxBank` (`data/audio/sfx_bank.tres`), `SfxPlayer` (24 pooled positional voices).
- Configs: `WeaponConfig.shot_sfx / reload_sfx / cycle_sfx`, `AttachmentConfig.shot_sfx` (silencer),
  `ThrowableConfig.blast_sfx`, `EnemyConfig.voice_sfx / voice_pitch / death_sfx`. `Gun.reload_sounds`,
  `Gun.dry_fires` counters.
- `game/spikes/spike_audio.gd`: shots (heard up to noise_m), reloads, pump, dry click, blasts, fire loop,
  groans by crowd size, deaths, Bloater pop, helmet clang, player hit, footsteps. F4: mute + volume.
- 5 new tests, 187 total, all passing on desktop. Desktop bot run: every event fired, peak 10 voices.

## Not done / next
- How it sounds is J's call (Claude can't listen). Swapping a take = one row in build_sfx.py SOUNDS.
- Footsteps per stance come with A3 (stances). A silencer on the AR would still play the pistol's silenced shot.
- Not tried on the Arc.

## J must test
- `?spike=arena&wave=4`, click once (browsers start audio on the first input). Each gun 1–4 sounds different;
  the silenced pistol is quiet; the shotgun pumps after each shot; R reloads with a sound; empty + no ammo clicks.
- Frag and incendiary blasts; the fire loop near burning zombies/floor; groans grow with the crowd; Runners shriek;
  Bloaters pop; a dropped helmet clangs; getting hit thuds.
- F4: "Sound volume (dB)" and "Sound off". Is anything too loud / too quiet / annoying when repeated?
