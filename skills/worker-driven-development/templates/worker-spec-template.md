# Supervised Worker Specification Template

Use this format when generating the `--spec` argument for `orca orchestration worker-start` or creating tasks with `orca orchestration task-create`.

---

```markdown
## Task Objective
[CLEAR, ACTIONABLE GOAL - e.g. "Implement user authentication middleware with JWT validation"]

## Target Files
- Modify: `src/auth/middleware.ts`
- Test: `tests/auth/middleware.test.ts`
- DO NOT touch files outside: `src/auth/` and `tests/auth/`

## Instructions & Methodology
1. **TDD is Mandatory**:
   - Run tests first to confirm existing baseline.
   - Write failing test for the new requirement.
   - Implement the minimal code required to pass the test.
   - Confirm all tests pass.
2. **Commit Policy**:
   - Make a clear, atomic git commit once tests pass.

## Verification Command
```bash
[EXACT TEST COMMAND - e.g. "npm test tests/auth/middleware.test.ts"]
```

## How to Report or Ask Questions
- **If you have a blocking question**: Run `ask` with your question. Orca will wake the coordinator and deliver the answer.
- **When task is completed**: Ensure git working tree is clean and all tests pass. Run `worker_done` with a summary of changes and verification evidence.
```
