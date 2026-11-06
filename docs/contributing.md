# Contributing (for agents and humans)

Several people work on this repo, each with their own AI agents. These conventions keep everyone
from stepping on each other.

## Before you start

1. `git fetch origin` and branch from the latest `origin/main`.
2. Read [status.md](status.md). If someone has your area "In flight", coordinate (comment on their
   PR or ask your human) instead of duplicating it.
3. For multi-step work, add a row to "In flight" in [status.md](status.md) in your first commit.
4. Check open PRs on GitHub for overlapping changes.

## Branches and commits

- Never push to `main`. Never force-push to someone else's branch.
- Branch names: `<area>/<short-description>`, e.g. `feed/video-cards`, `content/wikidata-import`,
  `fix/intro-card-overflow`, `docs/...`, `ci/...`. Agent-created branches with tool prefixes
  (e.g. `claude/...`) are fine.
- Small, focused commits with imperative messages ("Add fact card counter"). One concern per PR.
- Don't reformat files you aren't otherwise changing; it creates merge conflicts for others.

## Build and test

- macOS with Xcode 15+ and XcodeGen (`brew install xcodegen`).
- `xcodegen generate` after changing `project.yml` or adding/removing files (the `.xcodeproj` is
  git-ignored).
- Tests: `xcodebuild test -scheme AnimalScroller -destination 'platform=iOS Simulator,name=iPhone 15'`.
- CI (once PR #1 merges) runs the same on every PR. Don't merge red.
- If you can't build (for example you're in a Linux container), say so in the PR description so a
  human or Mac-based agent verifies it.
- Add or update unit tests for any change to `Services/` logic. Never delete or skip a test to
  get green.

## Species data

- Edit `tools/gen_taxonomy.py`, then run
  `python3 tools/gen_taxonomy.py AnimalScroller/Resources/taxonomy.json`. Commit both.
- Every species must be one specific species with an English Wikipedia article.
- Don't rename existing taxon ids (they're stored in user preferences).
- Update the species count in [status.md](status.md) and `README.md`.

## Before you open a PR

- [ ] Branched from current `main`; no unrelated changes
- [ ] Builds and tests pass (or the PR says why you couldn't run them)
- [ ] Content rules in [content-and-licensing.md](content-and-licensing.md) still hold
- [ ] [changelog.md](changelog.md) has a line under `Unreleased`
- [ ] [status.md](status.md) updated (state, known issues, "In flight" row added/removed)
- [ ] Any other affected doc updated (architecture, data model, product, design, roadmap)
- [ ] New choices recorded in [decisions.md](decisions.md) (`Proposed` unless a human decided)

## PR description

Use the template in `.github/pull_request_template.md`. Say what changed, why, how it was tested,
and which docs you updated. Mention who asked for the work.

## Resolving doc conflicts

`changelog.md` and `status.md` are touched by most PRs, so conflicts there are normal. Resolve by
keeping both sides' lines. For `decisions.md`, renumber your entry to the next free `D-NNN`.
