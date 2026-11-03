#!/usr/bin/env bash
# Gives the web build's engine files names unique to this build, so browsers never pair a cached old
# index.pck / index.wasm with a new page. GitHub Pages sends max-age=600, and a normal reload revalidates
# only the page itself, not what Godot's loader fetches.
# Usage: tools/web_cache_bust.sh <export dir> <tag>   (CI: build/web <commit>-<run number>)
set -euo pipefail
dir="$1"
tag="$2"
html="$dir/index.html"
grep -q '"executable":"index"' "$html" || { echo "::error::index.html has no \"executable\":\"index\""; exit 1; }
for f in "$dir"/index.js "$dir"/index.wasm "$dir"/index.pck "$dir"/index.audio.worklet.js \
		"$dir"/index.audio.position.worklet.js; do
	[ -f "$f" ] && mv "$f" "$dir/index-$tag${f#"$dir"/index}"
done
# The page loads index-<tag>.js; the engine finds the rest from "executable" (index-<tag>.wasm, .pck, ...).
sed -i -e "s/src=\"index\.js\"/src=\"index-$tag.js\"/" \
	-e "s/\"executable\":\"index\"/\"executable\":\"index-$tag\"/" \
	-e "s/\"index\.pck\":/\"index-$tag.pck\":/" \
	-e "s/\"index\.wasm\":/\"index-$tag.wasm\":/" "$html"
grep -q "src=\"index-$tag.js\"" "$html" || { echo "::error::index.html still loads index.js"; exit 1; }
ls "$dir"
