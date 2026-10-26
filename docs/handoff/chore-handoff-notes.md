# chore/handoff-notes

- **PR:** not opened (not pushed from the laptop CLI: no git credentials there; J pushes from GitHub Desktop)
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `5073dbb`
- **Updated:** 2026-10-26

## J asked
"พอจะทำส่วนที่ให้สองส่วนสองเครื่องนี้ส่งต่องานกันรู้เรื่องได้ไหม", then: "Build the handoff system on its own
branch from main: docs/handoff/, tools/handoff.sh and the CLAUDE.md section. Also write a handoff note for
the 0.5 branch."

## Done
- `docs/handoff/README.md` with the rules and a note template, plus this note.
- `tools/handoff.sh` session-start briefing. It shows:
  - this checkout's state
  - each unmerged branch with its note
  - files touched by more than one branch
- `CLAUDE.md` "Machines and handoff" section, and a `docs/DECISIONS.md` row.
- The 0.5 branch has its note (`phase0-spike-c-twin-stick.md`, on that branch).

## Not done / next
- PR #5 (`phase0/spike-b-desolate`, desktop) has no note yet. The desktop session should add one, including
  whether J's map/layout request ("ปรับดีไซน์ของแมพ แผนที่") is still open. PR #5 only changes mood and
  buildings, not the roof/map layout.

## J must test
Run `tools/handoff.sh` in Git Bash on each machine. It should list PR #5 and the 0.5 branch, and warn that
both touch `docs/DECISIONS.md` and `docs/PHASE0_RESULTS.md`.

## Next session must know
Until this branch merges, the rules exist only here. Read `CLAUDE.md` on this branch, or run
`git show origin/chore/handoff-notes:tools/handoff.sh | bash`.
