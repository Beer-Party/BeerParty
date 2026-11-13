# 2026-11-13: up to three PRs per run

- Asked for by Lev in chat: the agent should do more per daily session.
- `AGENT.md`: each run now repairs its open PRs first, then opens up to three new
  PRs (was one). New PRs stop once ten `agent` PRs are open (was three).
- Log entries move to one file per PR in `docs/agent/log/`, so PRs opened on the
  same day do not conflict in `AGENT_LOG.md`.
- The scheduled task's prompt was updated to match on the same day.
- Docs only; nothing to check on a device.
