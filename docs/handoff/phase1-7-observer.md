# phase1-7/observer

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ 460ddb7
- **Updated:** 2026-11-07

## J asked
"next" → 1.7 step 5 (the last of 1.7): Observer mode (GDD §4): one button hides the HUD, the camera drifts after
interesting activity, click a survivor for a short log ("reading the engine manual 3/5"); usable idle or for streams.

## Done
- `game/base/life_story.gd` (LifeStory, pure): what a survivor does in words — farm tasks by bed stage ("Watering
  the young cabbages"), building with hours, on watch, reading with days left, by the fire with whom, warming hands
  at a drum, asleep in a tent / cot / the infirmary / on the bare roof, resting with the injury; the card's lines
  (background, status, skill, class, traits, health/morale/needs, injuries, skills); `log_key` for the day log.
- `game/base/observer_director.gd` (ObserverDirector, pure): interest per activity (`roof_layout.json` "observer"),
  ×1.3 tending crops or building, + per companion within 3 m, recent subjects ×0.25; frames the group's middle; a
  drum-lighting errand cuts in.
- `ui/survivor_card.gd`: bottom-left card with the description, facts and the last 6 log lines ("10:00 Watering…").
- `base_spike`: O / pad Back toggles Observer (HUD, panel, tags hidden; build label stays; zoom one step in; a shot
  every 9 real s, tweened, slow drift); click a survivor or pad X for the card, Esc / B closes; with a card open in
  Observer the camera follows that survivor. `&observe=1`, `&card=<id>`. The stock bar fills from the first frame.
- 8 tests (`tests/game/test_observer.gd`); 393 passing. Captures `docs/art/28_base_observer.png`,
  `docs/art/29_survivor_card.png`.

## Not done / next
- 1.7 is complete with this PR. Zombies approaching (GDD's Observer example) come with 1.10's horde nights.
- Relationships on the card (GDD §7) wait for a relationship system.

## J must test
`?spike=base&rooms=tier1&hour=17&speed=2`, press O and leave it a few in-game hours: does the camera find the
interesting moments (people at the fire, farm work, someone lighting a drum) and does it feel calm, not jumpy?
Click a few people for their cards; with a card open in Observer, does following them work? Pad: Back, X, B.
