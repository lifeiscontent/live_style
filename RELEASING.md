# Releasing LiveStyle

This project uses automated releases via [git_ops](https://hexdocs.pm/git_ops) and GitHub Actions.

## How It Works

1. **Conventional Commits**: All commits must follow the [Conventional Commits](https://www.conventionalcommits.org/) format:
   - `feat:` - New features (bumps minor version)
   - `fix:` - Bug fixes (bumps patch version)
   - `chore:` - Maintenance tasks (no version bump)
   - `refactor:` - Code refactoring (no version bump)
   - `docs:` - Documentation changes (no version bump)

2. **Automatic Release**: When commits are pushed to `main`:
   - CI runs tests and Dialyzer
   - If tests pass, `mix git_ops.release --yes` runs automatically
   - If there are releasable commits (feat/fix), it:
     - Updates `CHANGELOG.md`
     - Bumps version in `mix.exs`
     - Creates a version commit and tag
     - Pushes to `main`

3. **Publish & GitHub Release**: The tag push triggers:
   - `mix hex.publish` to publish to Hex.pm
   - GitHub Release creation with changelog notes

## Requirements

- **RELEASE_TOKEN**: A GitHub Personal Access Token (PAT) with `contents: write` permission, stored as a repository secret. Required to bypass branch protection rules.
- **HEX_API_KEY**: Hex.pm API key for publishing, stored as a repository secret.

## Manual Release (if needed)

```bash
# Preview what would be released
mix git_ops.release --dry-run

# Create release
mix git_ops.release --yes

# Push
git push origin main --follow-tags
```

## Troubleshooting

### "No release needed"
If `git_ops.release` says no release is needed, it means there are no `feat:` or `fix:` commits since the last release. Only these commit types trigger version bumps.

### CI skips git_ops.release
The job skips if the commit message contains "chore: release version" (to prevent infinite loops when the release commit is pushed).
