---
name: commit-message
description: Commit and push code changes with a Conventional Commit message. Use when the user asks Codex to commit, commit and push, generate a commit from current changes, or invokes this skill after code edits.
---

# Commit Message

When this skill is invoked, commit and push the current changes directly. Do
not output a draft commit message for the user to copy.

Workflow:

- Run `git status --short` to inspect the worktree.
- Prefer existing staged changes. If nothing is staged, stage the current
  worktree changes with `git add -A`.
- Inspect the staged changes with `git diff --staged` before committing.
- If there are still no staged changes, stop and say there is nothing to
  commit.
- Generate a Conventional Commit message from the staged changes.
- Run `git commit` with the generated message.
- Run `git push` after the commit succeeds.
- Do not ask for confirmation or print the generated message before
  committing, unless command execution requires explicit tool approval or git
  refuses to continue.
- After success, keep the final response terse: say that the changes were
  committed and pushed. Do not include the commit message unless asked.

Commit message rules:

- Use Conventional Commit format: `<type>(<scope>): <subject>`.
- Use only these types: `build`, `ci`, `docs`, `feat`, `fix`, `perf`,
  `refactor`, `style`, `test`.
- Treat scope as optional. If present, use a lowercase short scope such as
  `api`, `runner`, or `ci`.
- Write the subject in imperative mood, without a trailing period, and keep it
  at 72 characters or fewer.
- Add a body separated from the subject by one blank line.
- Explain why and how the change was made, not just what changed.
- Wrap body lines at 72 characters or fewer.
- Keep the body concise and specific.
- Add a `BREAKING CHANGE:` footer when the change is breaking.
- Append `Refs: #123` when related issue or PR ids appear in context.
- Do not invent issue ids, scopes, or breaking-change footers.
