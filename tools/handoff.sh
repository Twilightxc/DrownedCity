#!/usr/bin/env bash
# Session-start briefing for work split across machines (see CLAUDE.md "Machines and handoff").
# Shows this checkout's state, every branch not yet merged into main with its handoff note,
# and files touched by more than one in-flight branch. Only `git fetch` writes anything.
#
# Usage: tools/handoff.sh [--no-fetch]
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

base=origin/main

note_path() { echo "docs/handoff/${1//\//-}.md"; }

indent() { sed 's/^/    /'; }

if [[ "${1:-}" != "--no-fetch" ]]; then
	git fetch --prune --quiet origin 2>/dev/null \
		|| echo "!! git fetch failed (offline or no credentials): showing the last fetched remote state"
fi

current=$(git branch --show-current)
echo "== This checkout"
echo "branch: ${current:-(detached)} @ $(git rev-parse --short HEAD)"
if upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) \
	&& git rev-parse --verify --quiet "$upstream" >/dev/null; then
	read -r behind ahead < <(git rev-list --left-right --count "$upstream...HEAD")
	echo "vs $upstream: $ahead ahead, $behind behind"
else
	echo "not on GitHub yet (no upstream): the other machine cannot see this branch"
fi
changes=$(git status --short)
if [[ -n "$changes" ]]; then
	echo "uncommitted (invisible to the other machine):"
	echo "$changes" | sed -n '1,20p' | indent  # sed reads to EOF: no SIGPIPE under pipefail
fi
stashes=$(git stash list)
if [[ -n "$stashes" ]]; then
	echo "stashes (GitHub Desktop stashes on branch switch):"
	echo "$stashes" | indent
fi
unpushed=$(git for-each-ref --format='%(refname:short)|%(upstream:short)|%(upstream:track)' refs/heads \
	| awk -F'|' '$2 == "" || $3 ~ /ahead/ { print $1 "  " ($2 == "" ? "(never pushed)" : $3) }')
if [[ -n "$unpushed" ]]; then
	echo "local branches with work not on GitHub:"
	echo "$unpushed" | indent
fi

echo
echo "== main ($base)"
git log --oneline -5 "$base" | indent

echo
echo "== In flight (pushed, not merged into main)"
touched=$(mktemp)
trap 'rm -f "$touched"' EXIT
found=0
while read -r ref; do
	[[ "$ref" == "origin/HEAD" || "$ref" == "origin" || "$ref" == "$base" ]] && continue
	found=1
	branch=${ref#origin/}
	echo
	echo "-- $branch: $(git rev-list --count "$base..$ref") commit(s) ahead of main"
	echo "   last: $(git log -1 --format='%h %cr, %an: %s' "$ref")"
	git diff --name-only "$base...$ref" | sed "s|$| $branch|" >> "$touched"
	note=$(note_path "$branch")
	if git cat-file -e "$ref:$note" 2>/dev/null; then
		git show "$ref:$note" | indent
	else
		echo "   (no handoff note at $note: read its commits/PR instead)"
		git log -5 --format='%h %s' "$base..$ref" | indent
	fi
done < <(git for-each-ref --format='%(refname:short)' --no-merged="$base" refs/remotes/origin)
[[ $found == 0 ]] && echo "(nothing: every pushed branch is merged)"

# This checkout's own committed, uncommitted and untracked files count too, pushed or not.
if [[ -n "$current" ]]; then
	{ git diff --name-only "$base...HEAD"; git diff --name-only HEAD; git ls-files --others --exclude-standard; } \
		| sort -u | sed "s|$| $current|" >> "$touched"
fi

echo
echo "== Files touched by more than one branch (expect merge conflicts)"
overlap=$(sort -u "$touched" | awk '{ n[$1]++; b[$1] = b[$1] "  " $2 } END { for (f in n) if (n[f] > 1) print f ":" b[f] }' | sort)
echo "${overlap:-(none)}" | indent
