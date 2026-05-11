# User Profile Instructions

## Code Review Workflow

- Before reviewing a PR, verify you are on the correct branch and have pulled the latest changes.
- Validate criticisms against existing codebase conventions (e.g., check sibling modules or review developer docs) before flagging them as issues.
- When reviewing, do not make claims about anti-patterns without grounding them in actual repo patterns.

## Git Commit Requirements

When updating code for any task, ALWAYS produce a git commit that explains the changeset.

Use the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/#specification) specification for commit messages:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Commit Types

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code (white-space, formatting, etc.)
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `build`: Changes that affect the build system or external dependencies
- `ci`: Changes to CI configuration files and scripts
- `chore`: Other changes that don't modify src or test files

### Examples

```
feat(auth): add OAuth2 support for GitHub login
fix: resolve null pointer exception in user service
docs: update API documentation for v2 endpoints
refactor(api)!: rename endpoints to follow REST conventions

BREAKING CHANGE: API endpoints have been renamed
```

## Test and Implementation Changes

- When library/dependency output differs from existing tests, update the tests to match the new correct output rather than normalizing the library output.
- When fixing log/telemetry rules, request a sample of the actual log/event structure before writing attribute references.

## Output Formats

- BUGBOT.md and `.cursor/` rule files should be formatted as Cursor bugbot reference guides (machine-readable rule files), NOT human-readable checklists
- When saving analysis/specs, default to {{ .defaultOutputFormat }} unless told otherwise.
