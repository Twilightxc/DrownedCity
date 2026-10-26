# Handoff notes

J works with Claude Code on two machines. Claude's memory stays on each machine, so **git is the only
shared channel**. Every branch carries one note that tells the next session, on either machine, what
happened and what is left.

- File: `docs/handoff/<branch with "/" → "-">.md`, committed **on that branch**. For example,
  `phase0/spike-c-twin-stick` → `phase0-spike-c-twin-stick.md`. Each branch has its own file, so notes
  never conflict on merge.
- Create it in the branch's first commit. Update it in any commit that changes the status, and always
  before a push or a machine switch.
- Notes on unmerged branches are live; `tools/handoff.sh` prints them. Once merged, a note is history.
  The decisions in it belong in `docs/DECISIONS.md` and the numbers in `docs/PHASE0_RESULTS.md`.
- English, short. Quote J's request in J's words (Thai is fine there), above all the parts not done yet.

## Template

```markdown
# <branch>

- **PR:** #n | not opened (pushed? yes/no)
- **Machine:** desktop (RTX 4080) | laptop (ASUS, Intel Arc 140V)
- **Base:** main @ <sha>, plus any other unmerged branch it depends on
- **Updated:** YYYY-MM-DD

## J asked
## Done
## Not done / next
## J must test
## Next session must know
Conflicts with other branches, dependencies, gotchas, anything this machine can or can't do.
```
