<!-- .factory/skills/review-guidelines/SKILL.md -->
<!--
  Review guidelines injected into all droid-action review prompts (code
  review, security review, validation passes). This file is repo-internal
  CI config — chezmoi ignores it via .chezmoiignore so it never deploys
  to ~/.factory/ (which is managed by private_dot_factory/ instead).
-->

# Review Comment Guidelines

## Findings only — never narrate the review process

Review comments must contain **concrete findings**: bugs, security issues,
correctness problems, and actionable suggestions. The PR author can read
the GitHub Actions run logs for process details.

### Do

- State each finding clearly with file, line, and why it matters.
- If no issues are found, post "LGTM" and nothing else.
- Ground every criticism in actual repo conventions.

### Don't

- Narrate workflow mechanics: passes, candidate queues, validation
  steps, model policy, reasoning effort, or internal pipeline details.
- Report on the review process itself ("candidate queue was empty",
  "no inline comments to post", "Pass 1 found …").
- Cite the PR body or your own prior output as validation evidence.
- Mention model names, API keys, or workflow configuration.
