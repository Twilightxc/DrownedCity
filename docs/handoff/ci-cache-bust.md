# ci/cache-bust

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ f4ed53d
- **Updated:** 2026-11-03

## J asked
After #38 deployed, J opened `?spike=arena&wave=4` and still got wave 1: the page showed build 1149e8f #96.
Pages sends `max-age=600`, and a reload revalidates only the page, so Godot's loader got the old index.pck.
J said "Yes, fix it" to cache-busting.

## Done
- `tools/web_cache_bust.sh <dir> <tag>` renames index.js / .wasm / .pck / audio worklets to `index-<tag>.*` and
  points index.html at them (`"executable"`, `fileSizes`, script src). CI runs it after the export with
  tag `<sha7>-<run number>`.
- Checked on a local export served from localhost: all three load (200), no console errors.

## Not done / next
- A page still cached from before a deploy asks for the old names, which are gone: a load error until the next
  reload. Rare (the page itself is revalidated on reload); accepted.

## J must test
- After the merge, open https://twilightxc.github.io/DrownedCity/?spike=arena&wave=4 with a normal reload (F5):
  the build label shows the new commit, the HUD says wave 4 / 6.
- From then on, every deploy should show up with a plain F5, without Incognito or waiting.
