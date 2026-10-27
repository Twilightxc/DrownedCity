# phase0/spike-d-save

- **PR:** not opened (pushed: yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ `e056e4a`
- **Updated:** 2026-10-27

## J asked
"มาทำงานต่อ" → picked "0.6 save บนเว็บ" (PHASE0.md 0.6).

## Done
- SimCore: `sim/sim_state.gd`, `sim/survivor.gd`, `sim/sim_rules.gd` + `data/sim/base_economy.tres`.
- `sim/save_codec.gd` (versioned JSON + migrations), `platform/save_store.gd` (user://, tmp + .bak),
  `platform/save_transfer.gd` (export/import, web + desktop).
- Spike scene `game/spikes/save_spike.tscn`, now the default URL (`?spike=save`).
- 16 new GUT tests (62 total, all pass). Checked on desktop GL and a local web export in the Claude pane:
  reload keeps the save. Results in `docs/PHASE0_RESULTS.md` 0.6.

## Not done / next
- J's pass test in Chrome: close the whole browser and reopen; export → import in another browser.
- Export/import not checked by Claude (needs a real download and file picker).

## J must test
1. Open the live URL (default is the save spike). If it still shows the rooftop, hard refresh (Ctrl+Shift+R):
   the browser may cache the old `index.pck`.
2. Press "Next day" 2–3 times, note the day and stock. Close every Chrome window, reopen the URL → same day.
3. "Export save file" → open the URL in Edge or Firefox → "Import save file" → pick the file → same day/stock.
4. Optional: gamepad D-pad/stick + A moves through the buttons.

## Next session must know
- The browser pane caches `index.pck` per origin: after a local export, open `http://127.0.0.1:8060/` (not
  `localhost`) or the old build loads.
- PowerShell in this sandbox cannot see `%APPDATA%\Godot\export_templates`; run the web export from Git Bash.
