Follow the Cold Start sequence (steps 0-9 from CLAUDE.framework.md — the canonical list lives there; CLAUDE.md merely @imports it).

Then:

1. Find tasks marked "Ready for Test" in TASKS.md
2. Do the pre-task context check. If projected >= 90%, ask user.
3. Delegate testing to the tester subagent using the Task tool:
   "Test [TASK-XXX]: [description].
   Contract: [read and include the relevant contract from ECOSYSTEM.md, or the matching file in `contracts/` if the project uses per-file contracts — see CLAUDE.md]
   Check GOTCHAS.md for known issues in this area.
   Write tests at the appropriate layer for what changed.
   Write findings to .claude/test-findings.md (NOT review-findings.md).
   Commit test files with task ID linkage.
   Update TASKS.md: move to Done if passing, back to In Progress if bugs found.
   Update STATUS.md with test results."

4. POST-DELEGATION VERIFICATION (mandatory — subagents may not update
   state files reliably):
   a. Read TASKS.md — did tasks move to "Done" or back to "In Progress"?
   b. Read STATUS.md — does it reflect test results?
   c. Read claude-progress.txt — is there a session entry?
   d. **Commit linkage check:** For tasks moving to "Done", verify
   `git log --oneline --grep="TASK-XXX"` returns at least one commit.
   A task cannot be marked Done without a linked commit.
   e. If ANY state files are missing, update them yourself from the subagent's output.
5. Commit all state file updates (include task/bug ID). Report test results to the user.
