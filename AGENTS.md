# Coding defaults

- Prefer small, localized patches; rewrite whole files only when incremental edits are riskier.
- Preserve behavior and existing architecture unless the task requires change.
- Avoid code smells; keep responsibilities cohesive and dependencies loosely coupled.
- Avoid duplication, speculative abstractions, and unrelated cleanup.
- Run the smallest relevant checks.
- Never create, amend, or otherwise finalize a Git commit unless the user explicitly asks for a commit in the current task. Completing implementation does not imply permission to commit.

# Commit attribution

- When authorized to commit, use `Ayan Mamun <ayan.mamun@icloud.com>` as both author and committer.
- Credit Codex in every Codex-assisted commit with the trailer `Co-authored-by: Codex <codex@openai.com>`.
- Never replace the user's author or committer identity with Codex.
