Please provide all answers in Japanese

## Herdr pane renaming

- When running inside Herdr (HERDR_ENV=1), once you understand the task, rename your pane with a short English title (2-4 words):
  ```bash
  herdr pane rename "$HERDR_PANE_ID" "fix oauth retry"
  ```
- Do this once per task without asking permission. Update it only if the direction of work changes clearly.

## Delegating work to other agents with Herdr

When the user asks you to have other agents work through Herdr, follow these rules in addition to the herdr skill:

- Create one worktree per task with `herdr worktree create --cwd <repo path> --branch <name> --no-focus`, and start the agent in the pane it opens.
- After starting a worker, mark its pane with you as the parent: `herdr pane report-metadata <pane> --source orchestrator --token parent=$HERDR_PANE_ID`.
- Hand out every task first, then wait. Do not wait for one agent to finish before prompting the next.
- Workers commit to their own branch and stop there. The user decides whether to merge.
- When you prompt a worker, tell it to end with a report: what changed, branch, commits, test results, open issues.
- Do not end your turn until every worker has finished or stopped. Collect each report with `herdr agent read` and summarize them for the user.
- When checking on workers, treat as yours only the agents in `herdr agent list` whose `tokens.parent` is your `$HERDR_PANE_ID` (`herdr agent list | jq -r --arg me "$HERDR_PANE_ID" '.result.agents[] | select(.tokens.parent == $me) | .name'`). Leave unmarked agents and agents marked by another pane alone, and tell the user you do not know their parent. Check the mark again before collecting a report, and drop a worker that has been re-marked by another pane.
- If the user asks you to take over workers from another parent, re-mark each of their panes with the same command so you are the parent. Do the same for an unmarked agent the user points you to. If the previous parent is still running, tell the user.
- If a worker stops at an approval or trust prompt, do not answer it; mention it in your report to the user. If a wait times out, wait again instead of resending the prompt.
