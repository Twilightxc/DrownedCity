# phase1/arena-wave-param

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ 1149e8f
- **Updated:** 2026-11-03

## J asked
J played the arena after #37 and saw no new zombie types: they reached only waves 1–2, and Armored comes in
wave 3, Bloater in wave 4. J said "Yes, add it" to a URL option for starting at a later wave.

## Done
- `?spike=arena&wave=N` (desktop: `-- --wave=N`) starts at wave N (1-based like the HUD, clamped). The calm
  before it still runs, so there is time to grab the crates.
- `SpikeLauncher.arg(key, fallback)`: the launcher's URL / command-line reader, now shared by spikes.
- `WaveDirector.new(cfg, seed, start_wave)`. The run log gets `start_wave`, so skipped-ahead runs can be told apart.
- 1 new test, 178 total, all passing on desktop.

## Not done / next
- Nothing on this branch.

## J must test
- https://twilightxc.github.io/DrownedCity/?spike=arena&wave=4 after the merge: the HUD says wave 4 / 6, and
  Runner, Armored and Bloater all come. This is the PR #37 playtest (types at a glance, helmet drop, limbs, Arc FPS).
