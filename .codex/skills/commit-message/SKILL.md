---
name: commit-message
description: Draft and print Conventional Commit messages for code changes. Use when the user asks Codex to write, generate, polish, or review a git commit message from git diff, staged changes, unstaged changes, PR context, issue ids, or repository changes.
---

# Commit Message

When this skill is invoked, inspect the current changes and print the final
commit message text for the user to commit manually.

Workflow:

- Run `git status --short` to inspect the worktree.
- Prefer existing staged changes and inspect them with `git diff --staged`.
- If nothing is staged, inspect unstaged changes with `git diff`.
- For untracked files, read the relevant file contents when needed.
- Do not run `git add`, `git commit`, or `git push`.
- If no changes are available, say there is nothing to commit.
- Generate a Conventional Commit message from the available changes.
- Output only the final commit message text. Do not use markdown, code
  fences, or extra commentary.

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
- Append `Co-authored-by: Codex <noreply@openai.com>` as the final footer.
- Do not invent issue ids, scopes, or breaking-change footers.
