# docs/arc-handoff

- **PR:** not opened (pushed: yes). This branch only carries this note, so `tools/handoff.sh` on the laptop shows
  it; merge or delete it once the Arc numbers are in `docs/PHASE0_RESULTS.md`.
- **Machine:** written on the desktop (RTX 4080), for the laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `097bd56` (0.7 parts 1–2 live, build `097bd56 · #52`)
- **Updated:** 2026-10-27

## J asked
"เตรียมสิ่งที่จำเป็นให้หน่อย พรุ่งนี้สลับเครื่อง ไปใช้เครื่อง arc"

## Done (desktop, 2026-10-27)
- Everything is merged and pushed; main is clean, no open branches besides this one.
- Merged today: GDD design pass + spike 0.8 (#12), save on web 0.6 ✅ (#13, #14), 0.5 gamepad deferred (#15),
  0.7 part 1 animated VAT horde (#16), 0.7 part 2 corpses / blood / dismemberment / gore toggle (#17).

## Not done / next
1. **Arc measurement (laptop, J)** — the first Arc run since the PR #4 look; it also covers the 0.4b look that J
   skipped. Steps below. Record the numbers in `docs/PHASE0_RESULTS.md`: the Arc rows of 0.4b and 0.7 (part 1
   and part 2 tables).
2. **0.7 part 3** — fake ragdoll slide on blasts, flying limbs as rigid bodies (cap 16), burning zombies (shader
   flag), ground fire cells in the NavGrid, then a second Arc run. Code only (no Blender), so the laptop can do
   it after downloading Godot 4.7.2 into the session scratchpad (ask J first, per CLAUDE.md).
3. **0.8 interiors** — needs the desktop (Blender interior kit).
4. Open questions for J: the demo cut list in GDD §17; Mixamo clips for the zombie (optional).

## J must test — Arc measurement
Before: laptop on power, Chrome only (close other tabs), Chrome window in front and not minimised (a background
tab is throttled and its FPS is not valid). Open each URL, press **Ctrl+Shift+R** once (Chrome may cache the old
`index.pck`), check the build label bottom-right reads `097bd56 · #52` or newer, press **F3** for the overlay.

| # | URL | What to do | Write down |
| --- | --- | --- | --- |
| A | `https://twilightxc.github.io/DrownedCity/?spike=style&autoshoot=1` | wait ~60 s (horde 200, the player shoots and throws grenades by itself; corpses fill toward 160) | FPS (and ms), Draw calls, Primitives, Horde Update, Corpses, Blood Pools, a screenshot with F3 |
| B | same page | press `]` once → 300 zombies, wait ~60 s | same |
| C | `https://twilightxc.github.io/DrownedCity/?spike=style` | no autoshoot: 200 zombies walking, packed on the player | FPS, Draw calls, Primitives |
| D | `https://twilightxc.github.io/DrownedCity/?spike=twinstick` | play 2–3 min with the mouse: shoot, throw grenades, F4 → "Blood + dismemberment" off and on | does the motion read as zombies; is the gore readable or cluttered |

Pass (PHASE0 0.7): ≥ 50 FPS, draw calls < 250, primitives < 300k. Desktop reference: A ≈ 56–70 draws, ~240k prims.

## Next session must know
- Laptop: `git push` from the CLI needs `GCM_INTERACTIVE=always` and `GIT_TERMINAL_PROMPT=1`; `gh` may need the full
  path `C:\Program Files\GitHub CLI\gh.exe` (CLAUDE.md, Machines and handoff).
- With autoshoot the crowd soon engulfs the player and new corpses pile up under it; that is expected.
- If A misses the budget, the levers already listed in PHASE0_RESULTS 0.7: no horde shadows on the far split,
  lower corpse cap (`data/fx/gore.tres`), coarser distant mesh, then 100 zombies.
- Gamepad test is deferred indefinitely by J; don't ask for it.
- An old GitHub Desktop stash (`stash@{0}`, phase0/spike-a-collision-fixes, only a `.pyc`) exists on the desktop
  checkout; it is not shared and needs nothing.
