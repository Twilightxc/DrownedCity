# chore/handoff-notes

- **PR:** not opened. Pushed up to `806c2a6`; the worktree commit after it still needs a push from GitHub Desktop.
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `5073dbb`
- **Updated:** 2026-10-26

## J asked
1. "พอจะทำส่วนที่ให้สองส่วนสองเครื่องนี้ส่งต่องานกันรู้เรื่องได้ไหม", then: "Build the handoff system on its own
   branch from main: docs/handoff/, tools/handoff.sh and the CLAUDE.md section. Also write a handoff note for
   the 0.5 branch."
2. About Claude sessions working in a separate git worktree: "ถ้าคิดว่าดีก็ทำได้เลย".

## Done
- `docs/handoff/README.md` with the rules and a note template, plus this note.
- `tools/handoff.sh` session-start briefing. It shows:
  - this checkout's state
  - each unmerged branch with its note
  - files touched by more than one branch
- `CLAUDE.md` "Machines and handoff" section, and a `docs/DECISIONS.md` row.
- The 0.5 branch has its note (`phase0-spike-c-twin-stick.md`, on that branch).
- Worktree rule in `CLAUDE.md`:
  - sessions work in `.claude/worktrees/<branch>`, never in the main checkout
  - remove the worktree after the last commit so GitHub Desktop can push the branch
- `.claude/worktrees/` is git-ignored. This commit itself was made from such a worktree.

## Not done / next
- PR #5 (`phase0/spike-b-desolate`, desktop) has no note yet. The desktop session should add one, including
  whether J's map/layout request ("ปรับดีไซน์ของแมพ แผนที่") is still open. PR #5 only changes mood and
  buildings, not the roof/map layout.
- Optional: J signs the laptop's git CLI in once (Git Credential Manager). Sessions could then push from their
  worktree and skip the remove-then-push-from-Desktop step.

## J must test
Run `tools/handoff.sh` in Git Bash on each machine. It should list PR #5 and the open branches, and warn which
files several branches touch (`docs/DECISIONS.md`, `docs/PHASE0_RESULTS.md`, `docs/PHASE0.md`).

## Next session must know
Until this branch merges, the rules exist only here. Read `CLAUDE.md` on this branch, or run
`git show origin/chore/handoff-notes:tools/handoff.sh | bash`. Until then, on the laptop the main checkout
hides `.claude/worktrees/` through `.git/info/exclude`, which is local and not committed.
