# Sound sources

Every sound in `assets/audio/` is cut from these packs by `tools/audio/build_sfx.py` (the cut for each file is a
row in its `SOUNDS` table). All are **CC0**: no credit is required, but each is credited in the game's credits.
J approved each download on 2026-11-03. The raw packs are not in the repo; to rebuild, download them into one
folder with the layout in the script's docstring and run `python tools/audio/build_sfx.py <folder>`.

| Pack | Author | Licence | Used for |
| --- | --- | --- | --- |
| [The Free Firearm Sound Library](https://opengameart.org/content/the-free-firearm-sound-library) (`Prepared SFX Library.7z`) | Ben Jaszczak, Brian Nelson, Kevin Heras, Matthew Nanney (Still North Media) | CC0 | shots: Walther PPQ (pistol, and the silenced shot filtered from it), AR-15, Benelli Nova (shotgun), Tikka T3 (DMR) |
| [Gun reload sounds](https://opengameart.org/content/gun-reload-sounds) | SpringySpringo | CC0 | reload_pistol, reload_rifle, pump_shotgun |
| [Chunky Explosion](https://opengameart.org/content/chunky-explosion) | Joth | CC0 | blast_frag |
| [Fire Staff Sound Effects](https://opengameart.org/content/fire-staff-sound-effects) | LEGIT Audio | CC0 | blast_incendiary |
| [Fireplace Sound loop](https://opengameart.org/content/fireplace-sound-loop) | PagDev | CC0 | fire_loop |
| [Zomby sfx pack](https://opengameart.org/content/zomby-sfx-pack) | saturn91 | CC0 | zombie_groan_1–6 |
| [Zombie noises and moans](https://opengameart.org/content/zombie-noises-and-moans) | ianzazz | CC0 | zombie_moan_1–3, zombie_alert (Runner) |
| [8 wet squish, slurp impacts](https://opengameart.org/content/8-wet-squish-slurp-impacts) | Independent.nu (submitted by qubodup) | CC0 | bloater_pop, flesh_hit_1–3 |
| [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 | footstep_1–5 (concrete), helmet_clang, player_hit, dry_click, shell_insert, hit_axe_1–2 (punches pitched down) |
| [Medieval sound effects – Weapon Textures](https://opengameart.org/content/medieval-sound-effects-weapon-textures) (`medieval_sfx_textures_1_of_2.7z`, `_2_of_2.7z`) | Ben Jaszczak, Brian Nelson (Still North Media) | CC0 | swing_knife_1–2 (Seax Swing), swing_axe_1–2 (Axe Swing). J approved the download 2026-11-06 |

Rejected while choosing (melee, 2026-11-06): "Medieval sound effects – Weapon impacts" (weapon on weapon, not on a
body), "Swishes sound pack" and Kenney "RPG Audio" (the Still North takes match the gun sounds). Earlier: "Gunshot Sounds" by Tabasco (heavy background noise), "Gunshots" by kurt (the uploader
did not own the guns, so the licence is unclear), "Tactical Weapons And Tactics" by XCVG (CC-BY, not CC0).
