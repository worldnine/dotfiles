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
- Hand out every task first, then wait. Do not wait for one agent to finish before prompting the next.
- Workers commit to their own branch and stop there. The user decides whether to merge.
- When you prompt a worker, tell it to end with a report: what changed, branch, commits, test results, open issues.
- Do not end your turn until every worker has finished or stopped. Collect each report with `herdr agent read` and summarize them for the user.
- If a worker stops at an approval or trust prompt, do not answer it; mention it in your report to the user. If a wait times out, wait again instead of resending the prompt.
