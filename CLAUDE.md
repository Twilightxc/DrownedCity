# Drowned City (working title)

Isometric survival-management + top-down action game. A post-outbreak city is flooded; the player runs a
rooftop community (State of Decay–style management) by day and defends it from hordes by night
(Boxhead-style action). Full design: `docs/GDD.md` (Thai). Decisions log: `docs/DECISIONS.md`.
Current phase and tasks: `docs/PHASE0.md`.

## Working with J (the developer)

- J is a computer engineer and part-time CE lecturer. Talk to J in **Thai**, concise and technical.
  Code, comments, commit messages, identifiers and in-game text are **English**.
- J has ≤ 5 h/day, no deadline. J owns playtesting and all "is this fun?" calls — Claude cannot play the
  game in real time. Make every build easy to test: build number on screen, debug overlay (F3), FPS counter.
- Don't add scope beyond the current phase without asking. Propose cuts when something grows.
- Hardware J tests on: desktop RTX 4080 (dev), laptop Intel Arc iGPU / Core Ultra (min-spec, web target).

## Platform plan (decided)

1. **Web demo** — GitHub Pages + itch.io, free. Proves the core loop, collects feedback/telemetry.
2. **Steam Early Access** → 3. **1.0**. Same repo, same code; only content flags, renderer preset and save
   backend differ.
- **Web stays free; Steam is the paid, upgraded version** (J, 2026-10-27). While in development the web build is
  free to play and grows with the game. When the Steam version goes on sale (Forward+ "High" preset, more detailed
  assets), the web build is cut back to a trial by the `demo_build` content flag. Web saves export as a file that
  the Steam version imports, so players keep their community. Say "free during development" on the web page from
  the start, so the cut is no surprise.

## Tech stack (decided)

- **Godot 4.x, GDScript only, static typing everywhere** (`var hp: int`, typed arrays, `-> void`).
  C# is NOT allowed: Godot still cannot export C# to web (as of Apr 2026). Heavy hot paths may later move
  to C++ GDExtension for desktop only — keep a GDScript fallback for web.
- Pin the Godot version in `.godot-version` and CI. Upgrade only deliberately.
- **Renderer: Compatibility (WebGL2)**. Web export **single-threaded** (no SharedArrayBuffer/COOP/COEP
  needed on GitHub Pages). Forward+ "High" preset is a later desktop-only extra.
- Camera: isometric **orthographic** 3D, rotatable in 90° steps, zoomable.
- Input: **mouse+keyboard AND gamepad from day one** (twin-stick). Every UI must be navigable by gamepad.
- Text: all strings via `tr()` + CSV translation table. English first; Thai later.
- Tests: GUT or gdUnit4 (pick one in Phase 0, then stick to it). SimCore must be unit-tested.

## Architecture rules (non-negotiable)

```
res://
  sim/          # SimCore: pure data + rules. NO Node, NO scene, NO rendering refs. RefCounted/Resource only.
                #   survivors, needs, skills, traits, base/rooms, economy tick, world/threat, weather, water level
  data/         # Tunables as .tres/.json: weapons, ammo, outfits, rooms, enemies, traits, missions, time pacing
  game/         # Presentation: scenes reading SimCore via signals. Camera, characters, water, UI
  combat/       # Real-time combat runtime: horde (MultiMesh), flow field, projectiles; reports results to SimCore
  ui/  audio/  telemetry/  platform/ (web vs desktop save backends, feature flags)
  tests/
tools/blender/  # Procedural asset scripts (bpy). Assets are generated, never hand-edited .glb
```

- **SimCore is the single source of truth.** Save = serialize SimCore (versioned schema + migrations).
- Simulation ticks per in-game hour; presentation interpolates. Fast-forward = run ticks without rendering.
- **Data-driven:** balance numbers live in `data/`, never hard-coded.
- **Content flags:** `demo_build` gates districts/rooms/weapons. Never fork code for the demo.
- Off-screen districts are simulated coarsely (threat values), never per-zombie.

## Performance budget (web, Intel Arc iGPU, Chrome)

60 FPS target (50 min) · draw calls < 250 · < 300k tris on screen · 200+ zombies (MultiMesh + shared flow
field, no per-agent NavigationAgent) · ≤ 6 base survivors in demo · texture atlas 2048² ×1–2 ·
first download < 50 MB · ≤ 4 dynamic lights per object · baked lighting where possible.
Any feature that breaks budget needs a cheaper fallback before merge.

## Art direction: "Style 1.5"

Reference images: `docs/art/03_style15_horde.png`, `docs/art/04_style15_horde_hud.png` (chosen).
`01`/`02` are rejected alternatives (too flat / too expensive for web).
- Low-poly, flat palette colours. Survivors warm & saturated; zombies pale green skin, cool grey clothes.
- Wet/algae stain on walls from world height (one `mix()` in shader, no noise). Murky green-teal water.
- One shadowed directional sun, low-angle dusk; emissive windows/fires + glow; depth fog.
- **Mood: abandoned and lonely** (J, 2026-10-26; `docs/art/06_desolate_vs_spike_b.png`). Bleached, desaturated
  city: rain streaks, peeling walls, broken/boarded windows, collapsed corners and roof holes, vines and moss,
  flotsam, sunken cars, dead lamps and trees in the water. Lit windows only where survivors live. Cooler
  light, slightly desaturated grade, thicker fog. Survivors stay warm so they read against it.
- Assets are built by `tools/blender/*.py` (Blender `bpy` 5.x via pip), exported as .glb. Keep scripts as the
  source of truth so variations are reproducible.

## Gameplay pillars (cut anything that serves none)

1. Every survivor matters (named, skilled, permadeath). 2. Water is everything (roads, walls, danger,
resource). 3. Risk is chosen (team size, noise, distance). 4. A living base you want to watch
(utility-AI daily life, Observer mode like The Division 2 settlements). 5. Readable at a glance.

## Workflow

- Small PRs per feature; each PR states what J should playtest and how.
- CI: GitHub Actions → headless Godot export Web → deploy to GitHub Pages on push to `main`.
- Never commit secrets; J adds API keys (itch.io butler, Supabase) to GitHub Secrets.
- Telemetry requires explicit opt-in consent; no personal data (PDPA).

## Machines and handoff

J runs Claude Code on two machines, often on different branches at the same time. Claude's memory is per
machine; **the repo is the only shared channel**, so whatever is not committed and pushed doesn't exist for
the other machine.

| Machine | Has | Use it for |
| --- | --- | --- |
| Desktop RTX 4080 (dev) | Godot, Blender, local web export | asset kits (`tools/blender`), captures, local web builds |
| Laptop ASUS, Intel Arc 140V (min-spec) | git, GitHub Desktop, `gh` 2.103 (logged in as Twilightxc since 2026-10-26; may need the full path `C:\Program Files\GitHub CLI\gh.exe` in old shells). No Godot or Blender. CLI `git push` works only with `GCM_INTERACTIVE=always` and `GIT_TERMINAL_PROMPT=1` set (Git Credential Manager login) | Arc measurements; code + GUT tests after downloading Godot into the session scratchpad (ask J first); open PRs with `gh` |

- **Session start:** run `tools/handoff.sh` (Git Bash) before any work. It fetches, then prints this
  checkout's state, every branch not merged into main with its handoff note, and files that more than one
  branch touches. Read the notes of branches that touch the same files as your task.
- **One note per branch:** `docs/handoff/<branch with / → ->.md`, on that branch. Format in
  `docs/handoff/README.md`. Create it in the first commit, keep it current, and always update it before a
  push or before J switches machines. Quote J's request there, especially the parts not done yet.
- **Before J switches machines:** commit, update the note, push.
- **Work in a git worktree, never in the main checkout** (`C:\DrownedCity` on the laptop is J's GitHub
  Desktop checkout; switching branches there stashed a session's work twice on 2026-10-26).
  - Start: `git worktree add .claude/worktrees/<branch with / → -> <branch>` (new branch:
    `-b <branch> origin/main`), then switch the session into it (Claude Code: `EnterWorktree` with `path`).
    Godot skips the hidden `.claude/` folder, and `.claude/worktrees/` is git-ignored.
  - Finish: push from the worktree when the user asked for a push or PR (laptop: with the two variables in the
    table above), then leave the worktree and `git worktree remove .claude/worktrees/<name>` from the main
    checkout. A branch checked out in a worktree can't be checked out in GitHub Desktop.
  - The stash is shared by all worktrees: never a bare `git stash pop`.
- GitHub Desktop may still switch the main checkout's branch and stash its changes. If files change on disk
  unexpectedly, check `git status -sb` and `git stash list` before editing.
- Parallel branches collide in `docs/DECISIONS.md` / `docs/PHASE0_RESULTS.md` (rows added at the top).
  Resolve by keeping both sides, newest first.
